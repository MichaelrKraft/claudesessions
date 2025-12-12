#!/bin/bash
# Save Current Claude Code Session On-Demand (v2.0)
# Called by /checkpoint slash command to archive the current session without exiting
# 
# Features:
# - Saves snapshot of current session
# - Generates AI summary
# - Indexes into SQLite for search
# - Supports custom tags

set -e

ARCHIVE_DIR="$HOME/.claude/session-archives"
LOG_FILE="$ARCHIVE_DIR/archiver.log"
CLAUDE_PROJECTS="$HOME/.claude/projects"
DB_MANAGER="$HOME/.claude/session-archiver/db-manager.sh"

log() {
    mkdir -p "$ARCHIVE_DIR"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG_FILE"
}

error_exit() {
    echo "ERROR: $1" >&2
    log "ERROR: $1"
    exit 1
}

# Get optional name/tag from argument
session_tag="${1:-checkpoint}"
# Sanitize tag (remove special chars)
session_tag=$(echo "$session_tag" | tr -cd '[:alnum:]-_')
[ -z "$session_tag" ] && session_tag="checkpoint"

mkdir -p "$ARCHIVE_DIR"

# Find the most recently modified transcript file (within last 2 hours)
latest_transcript=""
if [ -d "$CLAUDE_PROJECTS" ]; then
    latest_transcript=$(find "$CLAUDE_PROJECTS" -name "*.jsonl" -type f -mmin -120 2>/dev/null | \
        xargs ls -t 2>/dev/null | head -1)
fi

if [ -z "$latest_transcript" ] || [ ! -f "$latest_transcript" ]; then
    error_exit "No active session transcript found. This command works during an active Claude Code session."
fi

# Check if transcript has content
if [ ! -s "$latest_transcript" ]; then
    error_exit "Session transcript is empty. Have a conversation first!"
fi

# Extract session ID from filename
session_id=$(basename "$latest_transcript" .jsonl)
log "Manual save triggered for session: $session_id (tag: $session_tag)"

# Create timestamped archive
timestamp=$(date -u +%Y%m%d_%H%M%S)
archive_name="${timestamp}_${session_tag}_${session_id:0:8}"
session_archive="$ARCHIVE_DIR/$archive_name"

# Check if already saved recently (within 1 minute)
recent_save=$(find "$ARCHIVE_DIR" -maxdepth 1 -name "*_${session_id:0:8}" -mmin -1 2>/dev/null | head -1)
if [ -n "$recent_save" ]; then
    echo "NOTE: Session was already saved within the last minute."
    echo "Previous save: $(basename "$recent_save")"
    echo ""
fi

mkdir -p "$session_archive"

# Copy current transcript state
cp "$latest_transcript" "$session_archive/transcript.jsonl"
log "Copied transcript to: $session_archive/transcript.jsonl"

# Extract statistics with error handling
user_messages=$(jq -s '[.[] | select(.type == "user" or .type == "user_message")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")
assistant_messages=$(jq -s '[.[] | select(.type == "assistant" or .type == "assistant_message")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")
tool_calls=$(jq -s '[.[] | select(.type == "tool_use")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")
tools_used=$(jq -rs '[.[] | select(.type == "tool_use") | .tool_name] | unique | join(", ")' "$session_archive/transcript.jsonl" 2>/dev/null || echo "none")

# Get first user message as preview
first_message=$(jq -r '[.[] | select(.type == "user" or .type == "user_message")][0].content // "[No content]"' "$session_archive/transcript.jsonl" 2>/dev/null | head -c 300)

# Generate simple summary from content (fallback - no external API call)
summary="Session checkpoint: ${session_tag}. ${user_messages} exchanges covering: ${first_message:0:100}..."
echo "$summary" > "$session_archive/summary.txt"

# Create metadata
cat > "$session_archive/metadata.json" <<EOF
{
  "session_id": "$session_id",
  "archived_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "save_type": "manual",
  "tag": "$session_tag",
  "archive_name": "$archive_name",
  "original_transcript": "$latest_transcript",
  "stats": {
    "user_messages": $user_messages,
    "assistant_messages": $assistant_messages,
    "tool_calls": $tool_calls
  },
  "tools_used": "$tools_used",
  "preview": $(echo "$first_message" | jq -Rs '.')
}
EOF

# Create README
cat > "$session_archive/README.md" <<EOF
# Session Checkpoint: $archive_name

**Type:** Manual Save  
**Tag:** $session_tag  
**Session ID:** \`$session_id\`  
**Saved:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  

## Summary

$summary

## Statistics

| Metric | Count |
|--------|-------|
| User messages | $user_messages |
| Assistant messages | $assistant_messages |
| Tool calls | $tool_calls |

**Tools used:** $tools_used

## First Message

\`\`\`
$first_message
\`\`\`
EOF

# Index into database (if db-manager exists)
if [ -x "$DB_MANAGER" ]; then
    # Initialize DB if needed
    if [ ! -f "$ARCHIVE_DIR/sessions.db" ]; then
        "$DB_MANAGER" init 2>/dev/null || true
    fi
    "$DB_MANAGER" index "$session_archive" 2>/dev/null || true
fi

log "Manual save complete: $session_archive"

# Output for user - formatted nicely
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SESSION SAVED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Archive:  $archive_name"
echo "  Tag:      $session_tag"
echo ""
echo "  Stats:"
echo "    • User messages:      $user_messages"
echo "    • Assistant messages: $assistant_messages"
echo "    • Tool calls:         $tool_calls"
echo ""
echo "  Location: $session_archive"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Continue working - this is just a checkpoint!"
echo "  Use '/archives' to browse saved sessions."
echo ""
