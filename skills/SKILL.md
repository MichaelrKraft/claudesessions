---
name: session-archiver
description: |
  Archive, search, and continue Claude Code sessions with intelligent context management.
  Auto-activates when user mentions: save session, checkpoint, save progress, save this,
  session history, past sessions, what did we discuss, what did we decide, find session,
  search sessions, continue from, pick up where, resume session, yesterday's session,
  last time we, previous conversation, we talked about, we worked on, before I forget,
  milestone, breakpoint, good stopping point, let me save, archive this.
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Session Archiver Skill

## Purpose

I help you preserve, find, and continue your Claude Code work across sessions. I activate automatically when context suggests you want to save progress, search history, or resume previous work.

## When I Activate

### Saving Progress (Checkpoint Triggers)
- "Let me save this before we continue"
- "Good stopping point"
- "Before I forget this progress"
- "Checkpoint this"
- "Save this session"
- "Archive what we've done"

### Searching History (Search Triggers)
- "What did we decide about X?"
- "We talked about this before"
- "Find that session where we..."
- "Search my sessions for..."
- "When did we work on X?"
- "I remember we discussed..."

### Resuming Work (Continuation Triggers)
- "Continue from yesterday"
- "Pick up where we left off"
- "Resume the auth session"
- "Let's continue that work"
- "What were we doing last time?"

## Core Operations

### 1. Create Checkpoint

When you want to save progress, I run:

```bash
~/.claude/session-archiver/scripts/smart-checkpoint.sh "$TAG"
```

**What I do:**
1. Generate a meaningful tag from our conversation context if not provided
2. Save the session with metadata
3. Extract key decisions and outcomes
4. Index for future search
5. Confirm quietly: "Saved as: [tag]"

**Token efficiency:** Script handles archiving, I only output confirmation (~20 tokens)

### 2. Search Sessions

When you're looking for past work, I run:

```bash
~/.claude/session-archiver/scripts/smart-search.sh "$QUERY"
```

**What I return:**
- Top 3 most relevant sessions
- Date, tag, and relevance score
- 1-line summary of each match

**Token efficiency:** Script does full-text search and ranking, I only see condensed results (~150 tokens vs ~10,000 for raw search)

### 3. Continue Session

When you want to resume previous work, I run:

```bash
~/.claude/session-archiver/scripts/prepare-continuation.sh "$SESSION_ID"
```

**What I load:**
- Session date and working directory
- Key decisions made (bullet points)
- Last task in progress
- Critical context only

**Token efficiency:** ~500 tokens vs ~50,000 for full transcript (99% reduction)

### 4. Proactive Suggestions

At natural breakpoints, I may suggest saving:
- After completing a significant feature
- Before switching to a different task
- When you mention "done with this part"
- After resolving a complex bug

**I never interrupt flow** - suggestions are brief and optional.

## Token Efficiency Architecture

| Operation | Without Skill | With Skill | Savings |
|-----------|---------------|------------|---------|
| Search archives | ~10,000 tokens | ~150 tokens | 98.5% |
| View session | ~50,000 tokens | ~500 tokens | 99% |
| Create checkpoint | ~1,000 tokens | ~50 tokens | 95% |
| List sessions | ~2,000 tokens | ~200 tokens | 90% |

**How I achieve this:**
1. Scripts process data outside my context
2. Only results/summaries enter conversation
3. Full transcripts never load unless explicitly requested
4. Progressive disclosure: overview first, details on demand

## File Locations

| Item | Path |
|------|------|
| Archives | `~/.claude/session-archives/` |
| Database | `~/.claude/session-archives/sessions.db` |
| Scripts | `~/.claude/skills/session-archiver/scripts/` |
| CLI tools | `~/.claude/session-archiver/` |

## Available Scripts

### `smart-checkpoint.sh [tag]`
Creates checkpoint with optional tag. Auto-generates tag if not provided.

### `smart-search.sh <query>`
Full-text search with relevance ranking. Returns top 3 matches.

### `prepare-continuation.sh <session_id>`
Extracts minimal context for resuming a session.

### `find-related-sessions.py <topic> [--days=N]`
Finds sessions related to a topic within time range.

### `extract-key-points.py <transcript_path>`
Extracts decisions, outcomes, and key points from transcript.

### `session-stats.sh`
Shows archive statistics (count, total messages, storage used).

## Examples

### Example 1: Save Progress
```
User: "Good stopping point, let's save this"

Claude (me):
1. Analyze conversation for meaningful tag
2. Run: smart-checkpoint.sh "api-auth-implementation"
3. Output: "Checkpoint saved: api-auth-implementation
           Key points captured: JWT setup, refresh token logic, Redis session store"
```

### Example 2: Find Past Decision
```
User: "What database did we decide to use for the user service?"

Claude (me):
1. Run: smart-search.sh "database user service decision"
2. Get results:
   - 20251208_user-service: "Decided PostgreSQL with Prisma ORM" (relevance: 0.94)
   - 20251205_architecture: "Discussed DB options" (relevance: 0.72)
3. Output: "In the Dec 8 session, we decided on PostgreSQL with Prisma ORM for the user service."
```

### Example 3: Resume Work
```
User: "Let's continue the payment integration from yesterday"

Claude (me):
1. Run: find-related-sessions.py "payment" --days=7
2. Best match: 20251211_stripe-integration
3. Run: prepare-continuation.sh "20251211_stripe-integration"
4. Output: "Resuming payment integration session from Dec 11.

   **Context:**
   - Working directory: ~/projects/ecommerce
   - Implemented: Checkout session creation, webhook handler
   - In progress: Subscription management
   - Next task: Add subscription tier logic

   Ready to continue with subscription tiers?"
```

### Example 4: Proactive Suggestion
```
User: "Great, the auth flow is working now. Let's move on to the dashboard."

Claude (me):
[Detects task completion + context switch]
"Auth flow complete! Want me to checkpoint this as 'auth-flow-complete' before we switch to dashboard?"
```

## Error Handling

If scripts fail, I:
1. Report the error clearly
2. Suggest manual alternatives
3. Never leave you stuck

```
If search fails: "Search unavailable. You can manually browse: ls ~/.claude/session-archives/"
If checkpoint fails: "Couldn't auto-save. Manual: ~/.claude/session-archiver/save-now.sh [tag]"
```

## Supporting Documentation

- [search-guide.md](search-guide.md) - Advanced search techniques and query syntax
- [continuation-protocol.md](continuation-protocol.md) - How context restoration works
- [summary-patterns.md](summary-patterns.md) - What makes effective session summaries

## Integration with Existing Tools

This skill enhances but doesn't replace:
- `/checkpoint` - Still works for explicit saves
- `/archives` - Still works for explicit browsing
- CLI `sessions` command - Still available in terminal

The skill adds **intelligent automation** on top of these tools.
