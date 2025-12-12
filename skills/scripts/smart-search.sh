#!/bin/bash
# Smart Search Script for Session Archiver Skill
# Full-text search with relevance ranking
#
# Usage: smart-search.sh <query>
# Output: Top 3 results with relevance scores (~150 tokens)

set -e

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"

query="$1"

if [ -z "$query" ]; then
    echo "ERROR: No search query provided"
    echo "Usage: smart-search.sh <query>"
    exit 1
fi

# Check database exists
if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database not initialized"
    echo "Run: ~/.claude/session-archiver/db-manager.sh init"
    exit 1
fi

# Escape single quotes in query for SQL
safe_query=$(echo "$query" | sed "s/'/''/g")

# Perform FTS5 search with BM25 relevance ranking
fts_query="SELECT s.archive_name, s.archived_at, round(bm25(sessions_fts), 2) as relevance, COALESCE(substr(s.summary, 1, 100), substr(s.preview, 1, 100), '[No summary]') as snippet FROM sessions s JOIN sessions_fts fts ON s.id = fts.rowid WHERE sessions_fts MATCH '$safe_query' ORDER BY bm25(sessions_fts) LIMIT 3;"

results=$(sqlite3 -separator '|' "$DB_FILE" "$fts_query" 2>/dev/null || echo "")

if [ -z "$results" ]; then
    # Try broader search with LIKE as fallback
    like_query="SELECT archive_name, archived_at, '0.50' as relevance, COALESCE(substr(summary, 1, 100), substr(preview, 1, 100), '[No summary]') as snippet FROM sessions WHERE archive_name LIKE '%$safe_query%' OR summary LIKE '%$safe_query%' OR preview LIKE '%$safe_query%' ORDER BY archived_at DESC LIMIT 3;"

    results=$(sqlite3 -separator '|' "$DB_FILE" "$like_query" 2>/dev/null || echo "")
fi

if [ -z "$results" ]; then
    echo "NO MATCHES"
    echo ""
    echo "No sessions found matching: $query"
    echo ""
    echo "Try:"
    echo "  - Different keywords"
    echo "  - Broader search terms"
    echo "  - 'sessions list' to see all archives"
    exit 0
fi

# Format output for Claude (token-efficient)
echo "SEARCH RESULTS: $query"
echo ""

count=0
echo "$results" | while IFS='|' read -r name date relevance snippet; do
    count=$((count + 1))

    # Format date nicely
    formatted_date=$(echo "$date" | cut -d'T' -f1)

    # Clean up snippet
    clean_snippet=$(echo "$snippet" | tr -d '\n' | head -c 100)

    echo "$count. $name"
    echo "   Date: $formatted_date | Relevance: $relevance"
    echo "   $clean_snippet..."
    echo ""
done

echo "---"
echo "Use: prepare-continuation.sh <archive_name> to resume a session"
