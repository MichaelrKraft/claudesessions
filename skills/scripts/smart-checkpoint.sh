#!/bin/bash
# Smart Checkpoint Script for Session Archiver Skill
# Creates checkpoint and extracts key points for confirmation
#
# Usage: smart-checkpoint.sh [tag]
# Output: Condensed confirmation with key points (~50 tokens)

set -e

ARCHIVER_DIR="$HOME/.claude/session-archiver"
ARCHIVE_DIR="$HOME/.claude/session-archives"
SKILL_DIR="$HOME/.claude/skills/session-archiver"

# Get tag from argument or generate default
TAG="${1:-checkpoint}"

# Sanitize tag (remove special characters)
TAG=$(echo "$TAG" | tr -cd '[:alnum:]-_' | head -c 50)

# Run the existing save-now script
output=$("$ARCHIVER_DIR/save-now.sh" "$TAG" 2>&1) || {
    echo "ERROR: Checkpoint failed"
    echo "Details: $output"
    exit 1
}

# Extract archive name from output
archive_name=$(echo "$output" | grep -o 'Archive:[[:space:]]*[^[:space:]]*' | awk '{print $2}' | head -1)

if [ -z "$archive_name" ]; then
    # Try alternate extraction
    archive_name=$(echo "$output" | grep -oE '[0-9]{8}_[0-9]{6}_[^[:space:]]+' | head -1)
fi

# If we have an archive, extract key points
if [ -n "$archive_name" ] && [ -d "$ARCHIVE_DIR/$archive_name" ]; then
    transcript="$ARCHIVE_DIR/$archive_name/transcript.jsonl"

    # Extract key decisions/outcomes (token-efficient output)
    key_points=""
    if [ -f "$transcript" ]; then
        # Look for decision language in recent messages
        # Handle both .content and .message.content formats
        key_points=$(jq -r '
            # Extract content from various message formats
            (
                if .message.content then .message.content
                elif .content then .content
                else null
                end
            ) as $content |

            # Filter for messages with decision-like language
            select($content != null) |
            select(
                ($content | type == "string") and
                (
                    ($content | test("decided|will use|going with|chose|selected|implemented|completed|fixed|resolved"; "i"))
                )
            ) |
            $content
        ' "$transcript" 2>/dev/null |
        # Take last 5 decision-like messages, truncate each
        tail -5 |
        while IFS= read -r line; do
            # Truncate to 80 chars and add bullet
            echo "  - $(echo "$line" | head -c 80)..."
        done | head -5)
    fi

    # Output condensed confirmation
    echo "CHECKPOINT SAVED"
    echo ""
    echo "Archive: $archive_name"
    echo "Tag: $TAG"

    if [ -n "$key_points" ]; then
        echo ""
        echo "Key points captured:"
        echo "$key_points"
    fi

    echo ""
    echo "Continue working - this is just a checkpoint."
else
    # Fallback output if we can't find the archive
    echo "CHECKPOINT SAVED"
    echo ""
    echo "Tag: $TAG"
    echo ""
    echo "Continue working - this is just a checkpoint."
fi
