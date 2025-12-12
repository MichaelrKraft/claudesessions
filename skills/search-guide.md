# Session Search Guide

## Search Capabilities

The session archiver uses SQLite FTS5 (Full-Text Search) to enable fast, relevant searches across all archived sessions.

## Search Syntax

### Basic Search
```
smart-search.sh "authentication"
```
Finds sessions containing "authentication" anywhere.

### Multi-Word Search
```
smart-search.sh "user authentication flow"
```
Finds sessions containing all three words (not necessarily adjacent).

### Phrase Search
```
smart-search.sh '"JWT refresh token"'
```
Finds sessions with the exact phrase "JWT refresh token".

### OR Search
```
smart-search.sh "postgres OR mysql"
```
Finds sessions mentioning either PostgreSQL or MySQL.

### Prefix Search
```
smart-search.sh "auth*"
```
Finds sessions with words starting with "auth" (auth, authentication, authorize, etc.).

### Exclude Terms
```
smart-search.sh "database -postgres"
```
Finds sessions about databases but not PostgreSQL.

## What Gets Searched

The FTS index includes:
1. **Archive name** - The session tag/timestamp
2. **Preview** - First user message in the session
3. **Summary** - AI-generated session summary
4. **Transcript text** - Full conversation content

## Search Tips

### Finding Decisions
```
smart-search.sh "decided OR chose OR 'will use'"
```

### Finding Completed Work
```
smart-search.sh "completed OR implemented OR fixed"
```

### Finding By Project
```
smart-search.sh "ecommerce OR /projects/shop"
```

### Finding Recent Sessions
Use `find-related-sessions.py` with time filter:
```
find-related-sessions.py "api" --days=7
```

## Relevance Scoring

Results are ranked by BM25 relevance score:
- Higher scores = more relevant matches
- Exact phrase matches score higher
- Recent documents with matches score higher

## Troubleshooting

### "No matches found"
- Try broader terms
- Check spelling
- Use prefix search: `auth*`
- Browse all: `sessions list`

### Search seems slow
- Rebuild index: `db-manager.sh reindex`
- Check database size: `session-stats.sh`

### Wrong results ranked first
- Use more specific terms
- Try phrase search with quotes
- Filter by time with `--days`
