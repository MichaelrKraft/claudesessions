#!/bin/bash
# Claude Sessions - Auto-Context Injection
# Runs on SessionStart to load relevant past sessions
#
# This script silently injects context from previous sessions in the same project.
# If no relevant sessions exist, it exits silently without output.

set -e

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"
MAX_SESSIONS=3

# Exit silently if no database
if [ ! -f "$DB_FILE" ]; then
    exit 0
fi

# Get current working directory from hook input (JSON via stdin)
input=$(cat 2>/dev/null || echo "{}")
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null || echo "")

# Fallback to current directory if not provided
if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then
    cwd=$(pwd)
fi

# Detect project root by looking for common project markers
detect_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        # Check for common project root indicators
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/package.json" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/Cargo.toml" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/pyproject.toml" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/go.mod" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/Gemfile" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/pom.xml" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/build.gradle" ]; then
            echo "$dir"
            return 0
        elif [ -f "$dir/Makefile" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    # Fallback to original directory
    echo "$1"
}

project_root=$(detect_project_root "$cwd")
project_name=$(basename "$project_root")

# Query for recent sessions in this project
# Match on either project_root (if stored) or working_directory prefix
session_count=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(*) FROM sessions
    WHERE working_directory LIKE '$project_root%'
       OR project_root = '$project_root'
    LIMIT 1;
" 2>/dev/null || echo "0")

# Exit silently if no relevant sessions
if [ "$session_count" = "0" ] || [ -z "$session_count" ]; then
    exit 0
fi

# Output context header
echo ""
echo "=================================================="
echo "  PREVIOUS SESSION CONTEXT - $project_name"
echo "=================================================="
echo ""
echo "Project: $project_root"
echo "Found $session_count previous session(s) in this project."
echo ""

# Fetch and display recent session summaries
sqlite3 -separator '|' "$DB_FILE" "
    SELECT archive_name, archived_at,
           COALESCE(summary, substr(preview, 1, 200)) as context
    FROM sessions
    WHERE working_directory LIKE '$project_root%'
       OR project_root = '$project_root'
    ORDER BY archived_at DESC
    LIMIT $MAX_SESSIONS;
" 2>/dev/null | while IFS='|' read -r name date context; do
    # Format date more readably
    formatted_date=$(echo "$date" | cut -d'T' -f1)

    echo "--- Session: $name ---"
    echo "Date: $formatted_date"
    echo ""
    if [ -n "$context" ] && [ "$context" != "null" ]; then
        echo "$context"
    else
        echo "(No summary available)"
    fi
    echo ""
done

echo "=================================================="
echo "  END PREVIOUS CONTEXT"
echo "=================================================="
echo ""
echo "NOTE: This context is from previous sessions and may be outdated."
echo "Use 'sessions search <query>' to find specific past work."
echo ""

exit 0
