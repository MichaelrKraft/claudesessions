#!/bin/bash
# SQLite Database Manager for Session Archives
# Provides full-text search across all archived sessions

set -e

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"

# Escape string for safe SQL insertion (prevent SQL injection)
escape_sql() {
    local input="$1"
    # Double single quotes and remove any null bytes
    printf '%s' "$input" | sed "s/'/''/g" | tr -d '\0'
}

# Initialize database with FTS5 table
init_db() {
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    archive_name TEXT UNIQUE NOT NULL,
    session_id TEXT,
    archived_at TEXT,
    working_directory TEXT,
    project_root TEXT,
    project_name TEXT,
    exit_reason TEXT,
    user_messages INTEGER DEFAULT 0,
    assistant_messages INTEGER DEFAULT 0,
    tool_calls INTEGER DEFAULT 0,
    tools_used TEXT,
    preview TEXT,
    summary TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE VIRTUAL TABLE IF NOT EXISTS sessions_fts USING fts5(
    archive_name,
    preview,
    summary,
    transcript_text,
    content=''
);

CREATE TABLE IF NOT EXISTS transcript_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER REFERENCES sessions(id),
    chunk_type TEXT,
    content TEXT,
    tool_name TEXT,
    timestamp TEXT
);
EOF
    echo "Database initialized: $DB_FILE"
}

# Index a session into the database
index_session() {
    local archive_path="$1"
    local archive_name=$(basename "$archive_path")
    
    if [ ! -d "$archive_path" ]; then
        echo "Archive not found: $archive_path"
        return 1
    fi
    
    local metadata="$archive_path/metadata.json"
    local transcript="$archive_path/transcript.jsonl"
    local summary_file="$archive_path/summary.txt"
    
    if [ ! -f "$metadata" ]; then
        echo "Metadata not found for: $archive_name"
        return 1
    fi
    
    # Extract metadata
    local session_id=$(jq -r '.session_id // ""' "$metadata")
    local archived_at=$(jq -r '.archived_at // ""' "$metadata")
    local working_dir=$(jq -r '.working_directory // ""' "$metadata")
    local project_root=$(jq -r '.project_root // ""' "$metadata")
    local project_name=$(jq -r '.project_name // ""' "$metadata")
    local exit_reason=$(jq -r '.exit_reason // ""' "$metadata")
    local user_msgs=$(jq -r '.stats.user_messages // 0' "$metadata")
    local asst_msgs=$(jq -r '.stats.assistant_messages // 0' "$metadata")
    local tools=$(jq -r '.stats.tool_calls // 0' "$metadata")
    local tools_used=$(jq -r '.tools_used // ""' "$metadata")
    local preview=$(jq -r '.preview // ""' "$metadata" | sed "s/'/''/g")

    # If project_root not in metadata, try to detect from working_directory
    if [ -z "$project_root" ] && [ -n "$working_dir" ]; then
        # Detect project root retroactively
        local dir="$working_dir"
        while [ "$dir" != "/" ] && [ -n "$dir" ]; do
            if [ -d "$dir/.git" ] || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/go.mod" ]; then
                project_root="$dir"
                project_name=$(basename "$dir")
                break
            fi
            dir=$(dirname "$dir")
        done
        # Fallback to working_dir
        if [ -z "$project_root" ]; then
            project_root="$working_dir"
            project_name=$(basename "$working_dir")
        fi
    fi
    
    # Get summary if exists
    local summary=""
    if [ -f "$summary_file" ]; then
        summary=$(cat "$summary_file" | sed "s/'/''/g")
    fi
    
    # Extract full transcript text for FTS
    local transcript_text=""
    if [ -f "$transcript" ]; then
        transcript_text=$(jq -r '
            if .type == "user" or .type == "user_message" then
                .content // ""
            elif .type == "assistant" or .type == "assistant_message" then
                .content // .message // ""
            else
                empty
            end
        ' "$transcript" 2>/dev/null | tr '\n' ' ' | sed "s/'/''/g" | head -c 50000)
    fi
    
    # Insert into main table (upsert)
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO sessions (
    archive_name, session_id, archived_at, working_directory, project_root, project_name,
    exit_reason, user_messages, assistant_messages, tool_calls, tools_used, preview, summary
) VALUES (
    '$archive_name', '$session_id', '$archived_at', '$working_dir', '$project_root', '$project_name',
    '$exit_reason', $user_msgs, $asst_msgs, $tools, '$tools_used', '$preview', '$summary'
);
EOF
    
    # Get the session row id
    local row_id=$(sqlite3 "$DB_FILE" "SELECT id FROM sessions WHERE archive_name='$archive_name';")
    
    # Insert into FTS index
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO sessions_fts (rowid, archive_name, preview, summary, transcript_text)
VALUES ($row_id, '$archive_name', '$preview', '$summary', '$transcript_text');
EOF
    
    echo "Indexed: $archive_name"
}

# Reindex all sessions
reindex_all() {
    echo "Reindexing all sessions..."

    # Migration: Add project columns if they don't exist (for existing users)
    sqlite3 "$DB_FILE" "ALTER TABLE sessions ADD COLUMN project_root TEXT;" 2>/dev/null || true
    sqlite3 "$DB_FILE" "ALTER TABLE sessions ADD COLUMN project_name TEXT;" 2>/dev/null || true

    # Clear existing data (drop and recreate FTS5 table since contentless tables don't support DELETE)
    sqlite3 "$DB_FILE" "DROP TABLE IF EXISTS sessions_fts; DELETE FROM sessions;"
    sqlite3 "$DB_FILE" "CREATE VIRTUAL TABLE IF NOT EXISTS sessions_fts USING fts5(archive_name, preview, summary, transcript_text, content='');"
    
    # Index each archive
    for archive in "$ARCHIVE_DIR"/*/; do
        if [ -d "$archive" ] && [ -f "$archive/metadata.json" ]; then
            index_session "$archive" || true
        fi
    done
    
    echo "Reindex complete."
}

# Search sessions using FTS
search() {
    local query="$1"

    if [ -z "$query" ]; then
        echo "Usage: db-manager.sh search <query>"
        return 1
    fi

    # Escape query for SQL safety
    local escaped_query=$(escape_sql "$query")

    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT
    s.archive_name,
    s.archived_at,
    s.user_messages || ' msgs' as messages,
    substr(s.preview, 1, 60) || '...' as preview
FROM sessions s
JOIN sessions_fts fts ON s.id = fts.rowid
WHERE sessions_fts MATCH '$escaped_query'
ORDER BY s.archived_at DESC
LIMIT 20;
EOF
}

# Get session details
get_session() {
    local archive_name="$1"

    # Escape for SQL safety
    local escaped_name=$(escape_sql "$archive_name")

    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT * FROM sessions WHERE archive_name LIKE '%$escaped_name%' LIMIT 1;
EOF
}

# List recent sessions
list_recent() {
    local limit="${1:-10}"

    # Ensure limit is a number (prevent SQL injection)
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        limit=10
    fi

    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT
    archive_name,
    archived_at,
    user_messages || '/' || assistant_messages as 'usr/asst',
    tool_calls as tools,
    substr(preview, 1, 50) || '...' as preview
FROM sessions
ORDER BY archived_at DESC
LIMIT $limit;
EOF
}

# Stats
stats() {
    echo "=== Session Archive Statistics ==="
    echo ""
    
    sqlite3 "$DB_FILE" <<EOF
SELECT 
    COUNT(*) as total_sessions,
    SUM(user_messages) as total_user_messages,
    SUM(assistant_messages) as total_assistant_messages,
    SUM(tool_calls) as total_tool_calls
FROM sessions;
EOF
    
    echo ""
    echo "Most used tools:"
    sqlite3 "$DB_FILE" <<EOF
SELECT tools_used, COUNT(*) as count 
FROM sessions 
WHERE tools_used != '' 
GROUP BY tools_used 
ORDER BY count DESC 
LIMIT 5;
EOF
}

# === MAIN ===
case "${1:-help}" in
    init)       init_db ;;
    index)      index_session "$2" ;;
    reindex)    reindex_all ;;
    search)     search "$2" ;;
    get)        get_session "$2" ;;
    list)       list_recent "$2" ;;
    stats)      stats ;;
    *)
        echo "Session Archive Database Manager"
        echo ""
        echo "Usage: db-manager.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  init              Initialize the database"
        echo "  index <path>      Index a single session archive"
        echo "  reindex           Reindex all sessions"
        echo "  search <query>    Full-text search across sessions"
        echo "  get <name>        Get session details"
        echo "  list [n]          List recent sessions (default: 10)"
        echo "  stats             Show archive statistics"
        ;;
esac
