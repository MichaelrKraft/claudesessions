#!/usr/bin/env python3
"""
Find Related Sessions by Topic and Time Range

Searches session archives for sessions related to a topic,
optionally filtered by time range.

Usage:
    find-related-sessions.py <topic> [--days=N]

Output: Top 3 matching sessions with relevance info (~100 tokens)
"""

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path


def get_db_path() -> Path:
    """Get path to sessions database."""
    return Path.home() / ".claude" / "session-archives" / "sessions.db"


def get_archive_dir() -> Path:
    """Get path to archives directory."""
    return Path.home() / ".claude" / "session-archives"


def search_database(topic: str, days: int = None) -> list:
    """Search database for sessions matching topic."""
    db_path = get_db_path()

    if not db_path.exists():
        return []

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # Build date filter if specified
    date_filter = ""
    if days:
        cutoff = (datetime.now() - timedelta(days=days)).isoformat()
        date_filter = f"AND s.archived_at >= '{cutoff}'"

    # Escape topic for SQL
    safe_topic = topic.replace("'", "''")

    # Try FTS search first
    try:
        query = f"""
        SELECT
            s.archive_name,
            s.archived_at,
            s.working_directory,
            s.user_messages,
            COALESCE(s.summary, s.preview, '') as context,
            bm25(sessions_fts) as relevance
        FROM sessions s
        JOIN sessions_fts fts ON s.id = fts.rowid
        WHERE sessions_fts MATCH '{safe_topic}'
        {date_filter}
        ORDER BY bm25(sessions_fts)
        LIMIT 5
        """
        cursor.execute(query)
        results = cursor.fetchall()
    except sqlite3.OperationalError:
        results = []

    # Fallback to LIKE search if FTS returns nothing
    if not results:
        query = f"""
        SELECT
            archive_name,
            archived_at,
            working_directory,
            user_messages,
            COALESCE(summary, preview, '') as context,
            0.5 as relevance
        FROM sessions
        WHERE (
            archive_name LIKE '%{safe_topic}%' OR
            summary LIKE '%{safe_topic}%' OR
            preview LIKE '%{safe_topic}%'
        )
        {date_filter}
        ORDER BY archived_at DESC
        LIMIT 5
        """
        cursor.execute(query)
        results = cursor.fetchall()

    conn.close()
    return [dict(r) for r in results]


def search_filesystem(topic: str, days: int = None) -> list:
    """Fallback: search filesystem if database unavailable."""
    archive_dir = get_archive_dir()
    results = []

    if not archive_dir.exists():
        return results

    topic_lower = topic.lower()
    cutoff = None
    if days:
        cutoff = datetime.now() - timedelta(days=days)

    for session_dir in archive_dir.iterdir():
        if not session_dir.is_dir():
            continue

        metadata_file = session_dir / "metadata.json"
        if not metadata_file.exists():
            continue

        try:
            with open(metadata_file) as f:
                metadata = json.load(f)

            # Check date filter
            if cutoff:
                archived_at = metadata.get('archived_at', '')
                if archived_at:
                    try:
                        session_date = datetime.fromisoformat(archived_at.replace('Z', '+00:00'))
                        if session_date.replace(tzinfo=None) < cutoff:
                            continue
                    except (ValueError, TypeError):
                        pass

            # Check topic match
            searchable = ' '.join([
                session_dir.name,
                metadata.get('preview', ''),
                str(metadata.get('working_directory', ''))
            ]).lower()

            if topic_lower in searchable:
                results.append({
                    'archive_name': session_dir.name,
                    'archived_at': metadata.get('archived_at', 'unknown'),
                    'working_directory': metadata.get('working_directory', ''),
                    'user_messages': metadata.get('stats', {}).get('user_messages', 0),
                    'context': metadata.get('preview', '')[:100],
                    'relevance': 0.5
                })

        except (json.JSONDecodeError, IOError):
            continue

    # Sort by date, newest first
    results.sort(key=lambda x: x.get('archived_at', ''), reverse=True)
    return results[:5]


def format_output(results: list, topic: str, days: int = None) -> str:
    """Format results for token-efficient output."""
    lines = []

    time_range = f" (last {days} days)" if days else ""
    lines.append(f"RELATED SESSIONS: {topic}{time_range}")
    lines.append("")

    if not results:
        lines.append("No matching sessions found.")
        lines.append("")
        lines.append("Try:")
        lines.append("  - Different keywords")
        lines.append("  - Longer time range (--days=30)")
        lines.append("  - 'sessions list' to browse all")
        return '\n'.join(lines)

    for i, r in enumerate(results[:3], 1):
        name = r['archive_name']
        date = r['archived_at'][:10] if r['archived_at'] else 'unknown'
        relevance = abs(float(r.get('relevance', 0)))
        context = r.get('context', '')[:80]
        msgs = r.get('user_messages', 0)

        lines.append(f"{i}. {name}")
        lines.append(f"   Date: {date} | Messages: {msgs} | Relevance: {relevance:.2f}")
        if context:
            lines.append(f"   {context}...")
        lines.append("")

    lines.append("---")
    lines.append("Use: prepare-continuation.sh <archive_name> to resume")

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Find sessions related to a topic'
    )
    parser.add_argument('topic', help='Topic to search for')
    parser.add_argument(
        '--days', '-d',
        type=int,
        default=None,
        help='Only search sessions from last N days'
    )

    args = parser.parse_args()

    # Try database first, fall back to filesystem
    results = search_database(args.topic, args.days)
    if not results:
        results = search_filesystem(args.topic, args.days)

    output = format_output(results, args.topic, args.days)
    print(output)


if __name__ == "__main__":
    main()
