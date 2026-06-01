#!/bin/bash
# Coder1 Memory — Session Context Injection
# Runs on Claude Code SessionStart hook
# Outputs a structured morning standup briefing (stdout → injected as session context)
# Also writes a non-destructive context block to CLAUDE.md or .claude-context.md

# No set -e — sqlite3 calls may return non-zero safely and must not abort the script

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"

# Safe SQL string escape (prevents injection on paths with single quotes)
escape_sql() {
    printf '%s' "$1" | sed "s/'/''/g" | tr -d '\0'
}

# Safe sqlite3 query — returns empty string on error instead of aborting
q() {
    sqlite3 "$DB_FILE" "$1" 2>/dev/null || echo ""
}

# Exit silently if no database exists yet
[ -f "$DB_FILE" ] || exit 0

# Parse hook input from stdin
input=$(cat 2>/dev/null || echo "{}")
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)

# Detect project root by walking up from cwd
detect_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        for marker in ".git" "package.json" "Cargo.toml" "pyproject.toml" "go.mod" "Gemfile" "pom.xml" "build.gradle" "Makefile"; do
            [ -e "$dir/$marker" ] && { echo "$dir"; return 0; }
        done
        dir=$(dirname "$dir")
    done
    echo "$1"
}

project_root=$(detect_project_root "$cwd")
project_name=$(basename "$project_root")
esc_root=$(escape_sql "$project_root")

# Session count for this project
session_count=$(q "SELECT COUNT(*) FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root';")
[ -z "$session_count" ] && session_count=0

# First-run: no sessions yet
if ! [ "$session_count" -gt 0 ] 2>/dev/null; then
    echo ""
    echo "[coder1-mem] $project_name — No sessions yet. Your history builds automatically as you work."
    echo ""
    exit 0
fi

# Fetch last session data
last_summary=$(q "SELECT COALESCE(summary, preview, '') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
last_exit=$(q "SELECT COALESCE(exit_reason, 'normal') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
last_date=$(q "SELECT substr(archived_at, 1, 10) FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")

# ── Header ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "[coder1-mem] %s · %s sessions · last: %s\n" "$project_name" "$session_count" "$last_date"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Last Session ─────────────────────────────────────────────────────────────
echo "LAST SESSION"
if [ -n "$last_summary" ] && [ "$last_summary" != "null" ]; then
    short_summary=$(printf '%s' "$last_summary" | head -c 300)
    echo "  $short_summary"
else
    echo "  (No summary available — run 'sessions reindex' to build summaries)"
fi
echo ""

# ── Incomplete Session Detection ──────────────────────────────────────────────
if [ "$last_exit" = "interrupt" ] || [ "$last_exit" = "timeout" ]; then
    echo "⚠  INCOMPLETE SESSION DETECTED"
    # Best-effort: extract a file reference from the summary text
    last_file=$(printf '%s' "$last_summary" | grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|py|sh|go|rs|rb|json|md)' | head -1)
    if [ -n "$last_file" ]; then
        echo "   Last work involved: $last_file"
    fi
    echo "   → Resume this work, or describe a new task to start fresh."
    echo ""
fi

# ── Codebase ─────────────────────────────────────────────────────────────────
cb_row=$(q "SELECT language || '|' || framework || '|' || file_count || '|' || module_count || '|' || COALESCE(architecture_summary, '') FROM codebase_graph WHERE project_root='$esc_root';")
if [ -n "$cb_row" ]; then
    IFS='|' read -r cb_lang cb_framework cb_files cb_modules cb_arch <<< "$cb_row"
    echo "CODEBASE"
    echo "  $cb_lang · $cb_framework · $cb_files files · $cb_modules modules"
    [ -n "$cb_arch" ] && echo "  Architecture: $cb_arch"
    echo ""
fi

# ── Tip ───────────────────────────────────────────────────────────────────────
echo "Run 'sessions search <query>' to find specific past work."
echo ""

# ── CLAUDE.md Context Write (non-destructive, marker-based) ──────────────────
write_context_block() {
    local root="$1"
    local summary_text="$2"
    local exit_reason="$3"

    local target_file
    if [ -f "$root/CLAUDE.md" ]; then
        target_file="$root/CLAUDE.md"
    else
        target_file="$root/.claude-context.md"
    fi

    # Build block content
    local note=""
    if [ "$exit_reason" = "interrupt" ] || [ "$exit_reason" = "timeout" ]; then
        note="**Note:** Last session was interrupted — there may be incomplete work."
    fi

    # Write block to a temp file to avoid quoting issues with multiline content
    local tmpblock
    tmpblock=$(mktemp)
    cat > "$tmpblock" <<CONTEXTEOF

<!-- coder1-mem:start -->
<!-- Auto-updated by coder1-mem on $(date '+%Y-%m-%d') — do not edit this block manually -->
## Recent Session Context

**Project:** $project_name | **Sessions:** $session_count | **Last active:** $last_date

$(printf '%s' "$summary_text" | head -c 400)
${note}
<!-- coder1-mem:end -->
CONTEXTEOF

    if grep -q "coder1-mem:start" "$target_file" 2>/dev/null; then
        # Remove the existing block (start marker through end marker, inclusive)
        local tmpfile
        tmpfile=$(mktemp)
        awk '/<!-- coder1-mem:start -->/{skip=1} !skip{print} /<!-- coder1-mem:end -->/{skip=0}' "$target_file" > "$tmpfile"
        cat "$tmpblock" >> "$tmpfile"
        mv "$tmpfile" "$target_file"
    else
        cat "$tmpblock" >> "$target_file"
    fi

    rm -f "$tmpblock"
}

write_context_block "$project_root" "$last_summary" "$last_exit"

exit 0
