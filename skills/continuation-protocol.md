# Session Continuation Protocol

## Overview

Session continuation allows you to resume previous work with minimal context overhead. Instead of loading entire transcripts (~50,000 tokens), we extract only the essential context (~500 tokens).

## How Continuation Works

### 1. Session Discovery
When you say "continue the auth work", I:
1. Search for relevant sessions by keyword
2. Filter by recency if appropriate
3. Present top matches for confirmation

### 2. Context Extraction
For the selected session, I extract:
- **Metadata**: Date, directory, message counts
- **Summary**: AI-generated session summary
- **Key Decisions**: Statements with decision language
- **Completions**: Work marked as done
- **In Progress**: Tasks that were ongoing

### 3. Context Loading
I present ~500 tokens of focused context:
```
SESSION CONTINUATION CONTEXT
============================

**Session:** 20251210_auth-implementation
**Date:** 2024-12-10
**Directory:** ~/projects/myapp

## Summary
Implemented JWT authentication with refresh tokens...

## Key Points
**Key Decisions:**
- Using RS256 for JWT signing
- 15-minute access token expiry
- Redis for session storage

**Completed:**
- Login endpoint
- Token validation middleware
- Refresh token rotation

**In Progress:**
- Logout endpoint (invalidate refresh token)

============================
Ready to continue this session.
```

### 4. Seamless Continuation
You can now say "continue with the logout endpoint" and I have full context.

## Token Efficiency

| Approach | Tokens | Use Case |
|----------|--------|----------|
| Full transcript | ~50,000 | Never needed |
| Key points only | ~500 | Standard continuation |
| Minimal metadata | ~100 | Quick reference |

## Continuation Commands

### Via Natural Language
- "Continue the auth work from yesterday"
- "Pick up where we left off on the API"
- "Resume the database migration session"

### Via Script
```bash
# Find session
find-related-sessions.py "auth" --days=7

# Load context
prepare-continuation.sh 20251210_auth-implementation
```

## Best Practices

### When Saving Sessions
- Use descriptive tags: `auth-jwt-implementation` not `work`
- Save at logical breakpoints
- Note what's in progress

### When Resuming Sessions
- Be specific about what you want to continue
- Confirm the correct session before diving in
- Ask for more context if needed

## What's Preserved vs Lost

### Preserved in Continuation
- Key decisions and their rationale
- Completed tasks
- In-progress work
- Important context

### NOT Preserved (Intentionally)
- Debugging tangents
- Exploratory discussions
- Error messages and fixes
- Full code diffs

This is intentional - you want focused context, not noise.

## Manual Deep Dive

If you need the full transcript:
```bash
# View full transcript
cat ~/.claude/session-archives/[session]/transcript.jsonl | jq .

# Or in sessions CLI
sessions view [session] --full
```

But this is rarely needed - the key points capture what matters.
