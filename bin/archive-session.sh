#!/bin/bash
# Claude Code Session Archiver v2.0
# Automatically saves session transcripts with metadata and AI summaries
# 
# Features:
# - Captures complete conversation transcript
# - Extracts statistics (messages, tools, files)
# - Generates AI-powered session summary
# - Creates searchable archive

set -e

# === CONFIGURATION ===
ARCHIVE_DIR="$HOME/.claude/session-archives"
LOG_FILE="$ARCHIVE_DIR/archiver.log"
ARCHIVER_DIR="$HOME/.claude/session-archiver"

# === FUNCTIONS ===
log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG_FILE"
}

generate_ai_summary() {
    local transcript="$1"
    local output="$2"
    
    # Extract key content for summarization
    local conversation=$(jq -r '
        if .type == "user" or .type == "user_message" then
            "USER: " + ((.content // "[no content]") | tostring | .[0:300])
        elif .type == "assistant" or .type == "assistant_message" then
            "CLAUDE: " + ((.content // .message // "[no content]") | tostring | .[0:300])
        elif .type == "tool_use" then
            "TOOL[" + (.tool_name // "unknown") + "]"
        else
            empty
        end
    ' "$transcript" 2>/dev/null | head -100)
    
    if [ -z "$conversation" ]; then
        echo "No content to summarize." > "$output"
        return
    fi
    
    # Try to use Claude CLI for summary (with timeout)
    local prompt="Summarize this Claude Code session in 2-3 concise sentences. What was the goal and outcome?

$conversation

Summary:"
    
    # Attempt Claude CLI (timeout after 30s, fail gracefully)
    local summary
    summary=$(timeout 30 bash -c "echo '$prompt' | claude --print 2>/dev/null" 2>/dev/null || echo "")
    
    if [ -z "$summary" ]; then
        # Fallback: Create summary from first user message
        local first_msg=$(jq -r '[.[] | select(.type == "user" or .type == "user_message")][0].content // "No description"' "$transcript" 2>/dev/null | head -c 200)
        summary="Session topic: ${first_msg}..."
    fi
    
    echo "$summary" > "$output"
}

# === MAIN ===
mkdir -p "$ARCHIVE_DIR"

# Read hook input from stdin
input=$(cat)

# Extract values from JSON input
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
reason=$(echo "$input" | jq -r '.reason // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // ""')

log "Session ended: $session_id (reason: $reason)"

# Validate transcript exists
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    log "ERROR: Transcript not found at: $transcript_path"
    exit 0
fi

# Create timestamped archive folder
timestamp=$(date -u +%Y%m%d_%H%M%S)
archive_name="${timestamp}_${session_id:0:8}"
session_archive="$ARCHIVE_DIR/$archive_name"
mkdir -p "$session_archive"

# Copy the transcript
cp "$transcript_path" "$session_archive/transcript.jsonl"
log "Copied transcript to: $session_archive/transcript.jsonl"

# Extract session statistics
user_messages=$(jq -s '[.[] | select(.type == "user" or .type == "user_message")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")
assistant_messages=$(jq -s '[.[] | select(.type == "assistant" or .type == "assistant_message")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")
tool_calls=$(jq -s '[.[] | select(.type == "tool_use")] | length' "$session_archive/transcript.jsonl" 2>/dev/null || echo "0")

# Extract tools used
tools_used=$(jq -rs '[.[] | select(.type == "tool_use") | .tool_name] | unique | join(", ")' "$session_archive/transcript.jsonl" 2>/dev/null || echo "none")

# Get first user message as preview
first_message=$(jq -r '[.[] | select(.type == "user" or .type == "user_message")][0].content // "[No content]"' "$session_archive/transcript.jsonl" 2>/dev/null | head -c 300)

# Generate AI summary (runs in background to not block)
generate_ai_summary "$session_archive/transcript.jsonl" "$session_archive/summary.txt" &
summary_pid=$!

# Create metadata file
cat > "$session_archive/metadata.json" <<EOF
{
  "session_id": "$session_id",
  "archived_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "exit_reason": "$reason",
  "working_directory": "$cwd",
  "archive_name": "$archive_name",
  "stats": {
    "user_messages": $user_messages,
    "assistant_messages": $assistant_messages,
    "tool_calls": $tool_calls
  },
  "tools_used": "$tools_used",
  "preview": $(echo "$first_message" | jq -Rs '.')
}
EOF

# Wait for summary generation (max 30s)
wait $summary_pid 2>/dev/null || true

# Read summary if generated
summary_text="Summary pending..."
if [ -f "$session_archive/summary.txt" ]; then
    summary_text=$(cat "$session_archive/summary.txt")
fi

# Create human-readable README
cat > "$session_archive/README.md" <<EOF
# Session Archive: $archive_name

**Session ID:** \`$session_id\`  
**Archived:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Exit Reason:** $reason  
**Working Directory:** \`$cwd\`  

## AI Summary

$summary_text

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

## Files

- \`transcript.jsonl\` - Full conversation transcript
- \`metadata.json\` - Structured session metadata
- \`summary.txt\` - AI-generated summary
EOF

log "Archive complete: $session_archive"

# Output success message
echo "Session archived: $archive_name"

exit 0
