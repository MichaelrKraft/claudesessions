#!/bin/bash
# Generate AI summary for a session transcript
# Uses Claude CLI to create a concise summary

set -e

TRANSCRIPT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$TRANSCRIPT_FILE" ] || [ ! -f "$TRANSCRIPT_FILE" ]; then
    echo "Usage: generate-summary.sh <transcript.jsonl> <output.md>"
    exit 1
fi

# Extract conversation content for summarization
# Get user messages and assistant responses, format as readable text
conversation=$(jq -r '
    if .type == "user" or .type == "user_message" then
        "USER: " + (.content // "[no content]")
    elif .type == "assistant" or .type == "assistant_message" then
        "ASSISTANT: " + ((.content // .message // "[no content]") | tostring | .[0:500])
    elif .type == "tool_use" then
        "TOOL: " + (.tool_name // "unknown")
    else
        empty
    end
' "$TRANSCRIPT_FILE" 2>/dev/null | head -200)

if [ -z "$conversation" ]; then
    echo "No conversation content found"
    echo "# Session Summary\n\nNo content to summarize." > "$OUTPUT_FILE"
    exit 0
fi

# Create a prompt for Claude to summarize
summary_prompt="Summarize this Claude Code session in 2-3 sentences. What was the main goal? What was accomplished?

$conversation

Provide a concise summary (2-3 sentences max):"

# Use Claude CLI to generate summary (non-interactive, single response)
summary=$(echo "$summary_prompt" | claude --print-only 2>/dev/null || echo "Summary generation failed - Claude CLI not available")

# If Claude CLI failed, create a basic summary from the content
if [[ "$summary" == *"failed"* ]] || [ -z "$summary" ]; then
    # Fallback: extract first user message as summary
    first_message=$(jq -r '[.[] | select(.type == "user" or .type == "user_message")][0].content // "No description"' "$TRANSCRIPT_FILE" 2>/dev/null | head -c 200)
    summary="Session focused on: $first_message..."
fi

echo "$summary" > "$OUTPUT_FILE"
echo "Summary generated: $OUTPUT_FILE"
