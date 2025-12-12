#!/bin/bash
# Session Statistics Script for Session Archiver Skill
# Shows archive statistics in a token-efficient format
#
# Usage: session-stats.sh
# Output: ~100 tokens of statistics

ARCHIVE_DIR="$HOME/.claude/session-archives"
DB_FILE="$ARCHIVE_DIR/sessions.db"

echo "SESSION ARCHIVE STATISTICS"
echo "=========================="
echo ""

# Count archives
archive_count=$(ls -d "$ARCHIVE_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "**Total Sessions:** $archive_count"

# Storage used
storage=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
echo "**Storage Used:** $storage"

# Database stats if available
if [ -f "$DB_FILE" ]; then
    stats=$(sqlite3 "$DB_FILE" <<EOF 2>/dev/null
SELECT
    COUNT(*) as sessions,
    COALESCE(SUM(user_messages), 0) as user_msgs,
    COALESCE(SUM(assistant_messages), 0) as asst_msgs,
    COALESCE(SUM(tool_calls), 0) as tools
FROM sessions;
EOF
)

    if [ -n "$stats" ]; then
        sessions=$(echo "$stats" | cut -d'|' -f1)
        user_msgs=$(echo "$stats" | cut -d'|' -f2)
        asst_msgs=$(echo "$stats" | cut -d'|' -f3)
        tools=$(echo "$stats" | cut -d'|' -f4)

        echo "**Indexed:** $sessions sessions"
        echo ""
        echo "**Message Totals:**"
        echo "  - User messages: $user_msgs"
        echo "  - Assistant messages: $asst_msgs"
        echo "  - Tool calls: $tools"
    fi

    # Recent sessions
    echo ""
    echo "**Recent Sessions:**"
    sqlite3 "$DB_FILE" <<EOF 2>/dev/null | head -5
SELECT
    '  - ' || archive_name || ' (' || user_messages || ' msgs)'
FROM sessions
ORDER BY archived_at DESC
LIMIT 5;
EOF

else
    echo ""
    echo "**Note:** Database not initialized"
    echo "Run: ~/.claude/session-archiver/db-manager.sh init"
fi

echo ""
echo "=========================="
