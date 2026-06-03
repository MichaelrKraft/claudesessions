#!/bin/bash
# Coder1 Memory — Session Context Injection
#
# Default mode (called from SessionStart hook):
#   Emits a single-line status into Claude's context via hookSpecificOutput JSON.
#   Terse, signal-bearing, never noisy. Also writes a marker block to CLAUDE.md.
#
# --full mode (called from /recall slash command or explicit user invocation):
#   Prints the multi-line briefing directly to stdout (no JSON envelope, no CLAUDE.md write).
#   Visible in the terminal.

# No set -e — sqlite3/grep return non-zero safely and must not abort the script

FULL_MODE=false
case "${1:-}" in
    --full) FULL_MODE=true ;;
esac

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"

escape_sql() {
    printf '%s' "$1" | sed "s/'/''/g" | tr -d '\0'
}

q() {
    sqlite3 "$DB_FILE" "$1" 2>/dev/null || echo ""
}

emit_context() {
    local content="$1"
    [ -z "$content" ] && return 0
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg ctx "$content" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
    else
        local escaped
        escaped=$(printf '%s' "$content" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN{ORS="\\n"}1')
        printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$escaped"
    fi
}

# Relative time: "5min ago", "2h ago", "3d ago", "2w ago", or YYYY-MM-DD
relative_time() {
    local iso="$1"
    [ -z "$iso" ] && { echo "unknown"; return; }
    local then_epoch now_epoch diff
    then_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" "+%s" 2>/dev/null \
                 || date -u -d "$iso" "+%s" 2>/dev/null \
                 || echo "")
    [ -z "$then_epoch" ] && { echo "${iso:0:10}"; return; }
    now_epoch=$(date -u "+%s")
    diff=$((now_epoch - then_epoch))
    if   [ "$diff" -lt 60 ];      then echo "just now"
    elif [ "$diff" -lt 3600 ];    then echo "$((diff/60))min ago"
    elif [ "$diff" -lt 86400 ];   then echo "$((diff/3600))h ago"
    elif [ "$diff" -lt 604800 ];  then echo "$((diff/86400))d ago"
    elif [ "$diff" -lt 2592000 ]; then echo "$((diff/604800))w ago"
    else echo "${iso:0:10}"
    fi
}

# Extract an unresolved TODO from prior summary (best-effort regex).
# Echoes matched fragment (≤80 chars) or empty.
extract_todo() {
    local text="$1"
    [ -z "$text" ] && return 0
    local match
    match=$(printf '%s' "$text" | grep -oiE 'TODO:?[[:space:]]+[^.!?]{3,80}' | head -1)
    if [ -n "$match" ]; then
        printf '%s' "${match#*[Oo][Dd][Oo]}" | sed 's/^[: ]*//' | head -c 80; return
    fi
    match=$(printf '%s' "$text" | grep -oiE 'next:[[:space:]]+[^.!?]{3,80}' | head -1)
    if [ -n "$match" ]; then
        printf '%s' "${match#*[Nn]ext}" | sed 's/^[: ]*//' | head -c 80; return
    fi
    match=$(printf '%s' "$text" | grep -oiE 'still need(s|ed)? to [^.!?]{3,80}' | head -1)
    [ -n "$match" ] && { printf '%s' "$match" | head -c 80; return; }
    match=$(printf '%s' "$text" | grep -oiE 'want(s|ed)? to [^.!?]{3,80}' | head -1)
    [ -n "$match" ] && { printf '%s' "$match" | head -c 80; return; }
    match=$(printf '%s' "$text" | grep -oiE 'left [^.!?]{3,30} incomplete' | head -1)
    [ -n "$match" ] && { printf '%s' "$match" | head -c 80; return; }
    match=$(printf '%s' "$text" | grep -oiE 'not yet (done|finished|implemented|wired|hooked up)[^.!?]*' | head -1)
    [ -n "$match" ] && { printf '%s' "$match" | head -c 80; return; }
    return 0
}

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

write_claude_md_block() {
    local root="$1"
    local summary_text="$2"
    local exit_reason="$3"
    local proj="$4"
    local count="$5"
    local rel="$6"

    local target_file
    if [ -f "$root/CLAUDE.md" ]; then
        target_file="$root/CLAUDE.md"
    else
        target_file="$root/.claude-context.md"
    fi

    local note=""
    if [ "$exit_reason" = "timeout" ]; then
        note="**Note:** Last session timed out — there may be incomplete work."
    fi

    local tmpblock
    tmpblock=$(mktemp)
    cat > "$tmpblock" <<CONTEXTEOF

<!-- coder1-mem:start -->
<!-- Auto-updated by coder1-mem on $(date '+%Y-%m-%d') — do not edit this block manually -->
## Recent Session Context

**Project:** $proj | **Sessions:** $count | **Last active:** $rel

$(printf '%s' "$summary_text" | head -c 400)
${note}
<!-- coder1-mem:end -->
CONTEXTEOF

    if grep -q "coder1-mem:start" "$target_file" 2>/dev/null; then
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

# ── Exit silently if no database exists yet ──────────────────────────────────
[ -f "$DB_FILE" ] || exit 0

# ── Parse input ──────────────────────────────────────────────────────────────
if [ "$FULL_MODE" = true ]; then
    cwd=$(pwd)
else
    input=$(cat 2>/dev/null || echo "{}")
    cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || echo "")
    [ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
fi

project_root=$(detect_project_root "$cwd")
project_name=$(basename "$project_root")
esc_root=$(escape_sql "$project_root")

session_count=$(q "SELECT COUNT(*) FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root';")
[ -z "$session_count" ] && session_count=0

# ════════════════════════════════════════════════════════════════════════════
# DEFAULT MODE — single-line status into Claude's context
# ════════════════════════════════════════════════════════════════════════════
if [ "$FULL_MODE" = false ]; then
    # First-ever session in this project
    if ! [ "$session_count" -gt 0 ] 2>/dev/null; then
        emit_context "[coder1-mem] $project_name — new project, no history yet"
        exit 0
    fi

    last_summary=$(q "SELECT COALESCE(summary, preview, '') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
    last_exit=$(q "SELECT COALESCE(exit_reason, 'normal') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
    last_at=$(q "SELECT archived_at FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
    rel=$(relative_time "$last_at")

    # Decide the status line
    status_line=""
    if [ "$session_count" -le 5 ] 2>/dev/null; then
        status_line="[coder1-mem] $project_name · learning your workflow · $session_count/5 sessions · last $rel"
    else
        todo=$(extract_todo "$last_summary")
        if [ -n "$todo" ]; then
            todo_clean=$(printf '%s' "$todo" | sed 's/[[:space:]]*$//' | sed 's/[.!?,;:]*$//')
            status_line="[coder1-mem] $project_name · last session left TODO: \"$todo_clean\" · $rel"
        elif [ "$last_exit" = "timeout" ]; then
            last_file=$(printf '%s' "$last_summary" | grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|py|sh|go|rs|rb|json|md)' | head -1)
            if [ -n "$last_file" ]; then
                status_line="[coder1-mem] $project_name · last session timed out mid-edit on $last_file · $rel"
            else
                status_line="[coder1-mem] $project_name · last session timed out · $rel"
            fi
        else
            status_line="[coder1-mem] $project_name · $session_count sessions · last $rel"
        fi
    fi

    emit_context "$status_line"

    # Keep CLAUDE.md context block in sync (separate channel from hook injection)
    write_claude_md_block "$project_root" "$last_summary" "$last_exit" "$project_name" "$session_count" "$rel" 2>/dev/null

    exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# --full MODE — multi-line briefing to stdout (no JSON envelope, no CLAUDE.md write)
# ════════════════════════════════════════════════════════════════════════════

if ! [ "$session_count" -gt 0 ] 2>/dev/null; then
    echo ""
    echo "[coder1-mem] $project_name — new project, no history yet."
    echo "Your session history will start building automatically."
    echo ""
    exit 0
fi

last_summary=$(q "SELECT COALESCE(summary, preview, '') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
last_exit=$(q "SELECT COALESCE(exit_reason, 'normal') FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
last_at=$(q "SELECT archived_at FROM sessions WHERE working_directory LIKE '$esc_root%' OR project_root='$esc_root' ORDER BY archived_at DESC LIMIT 1;")
rel=$(relative_time "$last_at")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "[coder1-mem] %s · %s sessions · last %s\n" "$project_name" "$session_count" "$rel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "LAST SESSION"
if [ -n "$last_summary" ] && [ "$last_summary" != "null" ]; then
    printf '%s' "$last_summary" | head -c 300 | sed 's/^/  /'
    echo ""
else
    echo "  (No summary available — run 'sessions reindex' to build summaries)"
fi
echo ""

todo=$(extract_todo "$last_summary")
if [ -n "$todo" ]; then
    todo_clean=$(printf '%s' "$todo" | sed 's/[[:space:]]*$//' | sed 's/[.!?,;:]*$//')
    echo "UNRESOLVED"
    echo "  $todo_clean"
    echo ""
fi

if [ "$last_exit" = "timeout" ]; then
    echo "FLAG  last session timed out"
    last_file=$(printf '%s' "$last_summary" | grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|py|sh|go|rs|rb|json|md)' | head -1)
    [ -n "$last_file" ] && echo "      last edit: $last_file"
    echo ""
fi

cb_row=$(q "SELECT language || '|' || framework || '|' || file_count || '|' || module_count || '|' || COALESCE(architecture_summary, '') FROM codebase_graph WHERE project_root='$esc_root';")
if [ -n "$cb_row" ]; then
    IFS='|' read -r cb_lang cb_framework cb_files cb_modules cb_arch <<< "$cb_row"
    echo "CODEBASE"
    echo "  $cb_lang · $cb_framework · $cb_files files · $cb_modules modules"
    [ -n "$cb_arch" ] && echo "  architecture: $cb_arch"
    echo ""
fi

echo "Run 'sessions search <query>' to find specific past work."
echo "Run '/recall <query>' to surface matching sessions in chat."
echo ""

exit 0
