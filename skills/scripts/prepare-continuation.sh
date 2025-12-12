#!/bin/bash
# Prepare Continuation Context for Session Archiver Skill
# Extracts minimal context needed to resume a session
#
# Usage: prepare-continuation.sh <session_id_or_name>
# Output: ~500 tokens of focused context

set -e

ARCHIVE_DIR="$HOME/.claude/session-archives"
SKILL_SCRIPTS="$HOME/.claude/skills/session-archiver/scripts"

session_query="$1"

if [ -z "$session_query" ]; then
    echo "ERROR: No session specified"
    echo "Usage: prepare-continuation.sh <session_id_or_name>"
    echo ""
    echo "Find sessions with: smart-search.sh <query>"
    exit 1
fi

# Find the session directory (support partial matches)
session_dir=""
for dir in "$ARCHIVE_DIR"/*/; do
    dirname=$(basename "$dir")
    if [[ "$dirname" == *"$session_query"* ]]; then
        session_dir="$dir"
        break
    fi
done

if [ -z "$session_dir" ] || [ ! -d "$session_dir" ]; then
    echo "ERROR: Session not found: $session_query"
    echo ""
    echo "Available sessions:"
    ls -1 "$ARCHIVE_DIR" 2>/dev/null | head -5
    exit 1
fi

session_name=$(basename "$session_dir")
metadata="$session_dir/metadata.json"
transcript="$session_dir/transcript.jsonl"
summary="$session_dir/summary.txt"

# Start output
echo "SESSION CONTINUATION CONTEXT"
echo "============================"
echo ""

# Basic metadata
if [ -f "$metadata" ]; then
    archived_at=$(jq -r '.archived_at // "unknown"' "$metadata")
    working_dir=$(jq -r '.working_directory // "unknown"' "$metadata")
    user_msgs=$(jq -r '.stats.user_messages // 0' "$metadata")
    asst_msgs=$(jq -r '.stats.assistant_messages // 0' "$metadata")
    tools_used=$(jq -r '.tools_used // "none"' "$metadata")

    echo "**Session:** $session_name"
    echo "**Date:** $archived_at"
    echo "**Directory:** $working_dir"
    echo "**Messages:** $user_msgs user / $asst_msgs assistant"

    if [ "$tools_used" != "none" ] && [ -n "$tools_used" ]; then
        echo "**Tools Used:** $tools_used"
    fi
    echo ""
fi

# Summary if available
if [ -f "$summary" ] && [ -s "$summary" ]; then
    echo "## Summary"
    echo ""
    head -10 "$summary"
    echo ""
fi

# Extract key points using Python script
if [ -f "$transcript" ] && [ -f "$SKILL_SCRIPTS/extract-key-points.py" ]; then
    echo ""
    python3 "$SKILL_SCRIPTS/extract-key-points.py" "$transcript" 2>/dev/null || {
        # Fallback: show first and last user messages
        echo "## Context"
        echo ""
        echo "**First request:**"
        jq -r 'select(.type == "user" or (.message.role == "user")) | .message.content // .content' "$transcript" 2>/dev/null | head -1 | head -c 200
        echo "..."
        echo ""
        echo "**Last request:**"
        jq -r 'select(.type == "user" or (.message.role == "user")) | .message.content // .content' "$transcript" 2>/dev/null | tail -1 | head -c 200
        echo "..."
    }
fi

echo ""
echo "============================"
echo "Ready to continue this session."
echo "Ask me to pick up where you left off."
