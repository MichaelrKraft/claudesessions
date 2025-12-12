# Launch Posts for Claude Sessions

All posts are drafts for your review before posting.

---

## Reddit r/ClaudeAI Post

**Subreddit**: r/ClaudeAI

**Title**: I built a session archiver for Claude Code - auto-saves your work, full-text search, never lose context again (free/open source)

**Body**:

```markdown
Hey everyone,

I've been using Claude Code daily and kept running into the same problem: closing a session and losing valuable context. Starting fresh every time is painful, especially for long-running projects.

So I built **Claude Sessions** - a simple tool that:

- **Auto-archives** every session when you exit (via Claude Code hooks)
- **Full-text search** across all your past work (SQLite FTS5)
- **Manual checkpoints** with `/checkpoint` for important milestones
- **Key point extraction** - AI pulls out decisions, completions, and in-progress work
- **Web dashboard** to browse your archive visually
- **Token efficient** - resume with ~500 tokens instead of ~50,000

**Install in 30 seconds:**

```bash
curl -fsSL https://claudesessions.com/install.sh | bash
```

Then just use Claude Code normally. Sessions archive automatically when you exit.

**Search your history:**
```bash
sessions search "authentication bug"
sessions list
sessions view my-project-checkpoint
```

It's completely free and open source: https://github.com/michaelcraft/claudesessions

The idea is simple: your Claude Code sessions are valuable. They contain decisions, context, and work that shouldn't disappear when you close the terminal.

Would love feedback! What features would make this more useful for your workflow?

---

*Built this because I was tired of re-explaining project context every time I started a new session. Hope it helps others too.*
```

**Flair**: Tool/Resource (if available)

---

## Hacker News "Show HN" Post

**Title**: Show HN: Claude Sessions – Auto-archive and search your Claude Code CLI sessions

**URL**: https://claudesessions.com (or https://github.com/michaelcraft/claudesessions)

**Text** (for text post, if not using URL):

```
I built Claude Sessions to solve my own frustration with losing context between Claude Code sessions.

The problem: Claude Code (Anthropic's CLI tool) starts fresh each time. For long-running projects, you lose valuable context - decisions made, approaches tried, code written.

The solution: Claude Sessions auto-archives every session when you exit. It uses Claude Code's hook system to trigger on SessionEnd, extracts key points (decisions, completions, blockers), and stores everything in SQLite with FTS5 for instant search.

Key features:
- One-line install: curl -fsSL https://claudesessions.com/install.sh | bash
- Auto-archive on session exit (zero friction)
- Full-text search: sessions search "your query"
- Manual checkpoints: /checkpoint milestone-name
- Web UI for browsing: sessions web
- Token-efficient summaries (~500 tokens vs ~50,000 transcripts)

Tech stack: Bash scripts, SQLite FTS5, Node.js (web UI), Python (key point extraction).

Free and open source (MIT). Would love feedback on what would make this more useful.

GitHub: https://github.com/michaelcraft/claudesessions
```

---

## Twitter/X Thread

**Tweet 1 (Main):**

```
I built Claude Sessions - never lose context from Claude Code again.

- Auto-archives every session
- Full-text search across all work
- Resume with AI-extracted key points

One-line install:
curl -fsSL https://claudesessions.com/install.sh | bash

Free & open source 🧵
```

**Tweet 2:**

```
The problem: Claude Code starts fresh every time.

For complex projects, you end up re-explaining context, re-making decisions, losing momentum.

Claude Sessions captures everything automatically when you exit.
```

**Tweet 3:**

```
What gets saved:
- Full conversation transcript
- Git status at time of archive
- AI-extracted key points:
  • Decisions made
  • Tasks completed
  • Work in progress
  • Blockers encountered
```

**Tweet 4:**

```
Search is instant:

sessions search "authentication flow"
sessions search "bug fix"
sessions list --project myapp

SQLite FTS5 with BM25 ranking. Find anything in seconds.
```

**Tweet 5:**

```
Resume with context, not transcripts:

Instead of loading 50,000 tokens of conversation, Claude Sessions extracts ~500 tokens of key points.

Same context. 1% of the cost.
```

**Tweet 6:**

```
Try it:

1. Install: curl -fsSL https://claudesessions.com/install.sh | bash
2. Use Claude Code normally
3. Exit → session auto-archived
4. Search: sessions search "your query"

GitHub: github.com/michaelcraft/claudesessions

Feedback welcome!
```

---

## LinkedIn Post (Optional)

```
Developers using Claude Code: do you ever lose valuable context when closing a session?

I built Claude Sessions to solve this.

🔄 Auto-archives every session when you exit
🔍 Full-text search across all your work
💾 Manual checkpoints for milestones
📊 AI extracts decisions, completions, and blockers
⚡ Token-efficient summaries for resumption

One-line install:
curl -fsSL https://claudesessions.com/install.sh | bash

Free and open source.

The idea is simple: your Claude Code sessions contain valuable decisions and context. They shouldn't disappear when you close the terminal.

GitHub: https://github.com/michaelcraft/claudesessions

What features would make this more useful for your workflow?

#ClaudeAI #DeveloperTools #AI #OpenSource
```

---

## Post Timing Recommendations

**Reddit r/ClaudeAI:**
- Best times: Weekday mornings (9-11am EST)
- Engage with comments quickly
- Be ready to answer technical questions

**Hacker News:**
- Best times: Weekday mornings (9-11am EST)
- First 30 minutes are critical for traction
- Respond to all comments promptly

**Twitter/X:**
- Best times: Weekday mornings or lunch (12-1pm)
- Post thread all at once
- Engage with replies

## Before Posting Checklist

- [ ] GitHub repo is public
- [ ] install.sh is tested and working
- [ ] Landing page is live
- [ ] Demo video/GIF is ready (optional but recommended)
- [ ] You're available to respond to comments for 2-3 hours after posting
