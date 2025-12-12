# Claude Sessions

> Never lose context again.

**Claude Sessions** automatically archives your Claude Code sessions, making them searchable and resumable with minimal token overhead.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-orange.svg)](https://claude.ai/code)

---

## The Problem

Every time you start a new Claude Code session, you lose:
- **Decisions** you made and why
- **Progress** on multi-day projects
- **Context** that took hours to build

Starting fresh means re-explaining your project, re-discovering edge cases, and re-making decisions you already made.

## The Solution

Claude Sessions automatically captures your sessions and extracts the **essential context** - decisions, completions, and work in progress. When you return, you get ~500 tokens of focused context instead of re-loading 50,000 tokens of transcript.

```
┌─────────────────────────────────────────────────────────┐
│  "Continue the auth work from yesterday"                │
│                                                         │
│  ✓ Found: 20251210_auth-implementation                  │
│  ✓ Loaded 487 tokens of key context                     │
│  ✓ Ready to continue                                    │
│                                                         │
│  Key Decisions:                                         │
│  - Using RS256 for JWT signing                          │
│  - 15-minute access tokens, 7-day refresh tokens        │
│  - Redis for session storage                            │
│                                                         │
│  In Progress:                                           │
│  - Logout endpoint (invalidate refresh token)           │
└─────────────────────────────────────────────────────────┘
```

## Quick Install

```bash
curl -fsSL https://claudesessions.com/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/michaelcraft/claudesessions.git ~/.claudesessions
~/.claudesessions/install.sh
```

## Features

### Auto-Archive on Exit
Every session is automatically saved when you exit Claude Code. No manual action required.

### Smart Search
Full-text search with relevance ranking across all your sessions:

```bash
sessions search "authentication"
sessions search "postgres OR mysql"
sessions search "database -postgres"  # exclude postgres
```

### Session Continuation
Resume previous work with minimal context loading:

```
> Continue the API work from last week

SESSION CONTINUATION CONTEXT
============================
Session: 20251205_api-refactor
Date: 2024-12-05

## Key Decisions
- Switching from REST to GraphQL
- Using DataLoader for N+1 prevention

## Completed
- Schema definitions
- User resolver

## In Progress
- Product resolver with pagination
============================
```

### Manual Checkpoints
Save important milestones with descriptive tags:

```
/checkpoint auth-complete
/checkpoint before-refactor
/checkpoint v2-release
```

### Web Dashboard
Browse your archive visually:

```bash
sessions web
# Opens http://localhost:3456
```

## How It Works

### Architecture

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Claude Code     │───▶│  Session Hook    │───▶│  Archive Store   │
│  (your session)  │    │  (auto-capture)  │    │  (SQLite + FTS5) │
└──────────────────┘    └──────────────────┘    └──────────────────┘
                                                         │
                        ┌──────────────────┐             │
                        │  Key Points      │◀────────────┘
                        │  Extractor       │
                        │  (~500 tokens)   │
                        └──────────────────┘
```

### Token Efficiency

| Approach | Tokens | Use Case |
|----------|--------|----------|
| Full transcript | ~50,000 | Never needed |
| Key points only | ~500 | Standard continuation |
| Minimal metadata | ~100 | Quick reference |

### What Gets Extracted

- **Decisions**: "decided to...", "will use...", "chose..."
- **Completions**: "completed...", "finished...", "implemented..."
- **In Progress**: "next:", "todo:", "still need to..."
- **Outcomes**: "result:", "conclusion:", "in summary..."

## Commands

### CLI

```bash
# List all archives
sessions list

# Search archives
sessions search "keyword"

# View archive details
sessions view <archive-name>

# Show statistics
sessions stats

# Start web UI
sessions web
```

### Claude Code

```
/checkpoint <tag>     # Save current session with tag
/archives             # Browse archived sessions
```

## Configuration

Settings are in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [{
      "type": "command",
      "command": "~/.claudesessions/archive-session.sh"
    }]
  }
}
```

## Requirements

- Claude Code CLI
- Node.js 18+
- SQLite 3.x
- jq

## Privacy

**Free Tier:** All data stays on your machine. No cloud, no telemetry, no external connections. Your sessions are stored in `~/.claude/session-archives/`.

**Pro Tier (Coming Soon):** Optional encrypted cloud backup with end-to-end encryption. You control your data. Export anytime.

## Roadmap

### Coming in Pro (Q1 2025)
- [ ] **Cloud Backup**: Encrypted cloud storage for your sessions
- [ ] **Multi-Device Sync**: Access your archives from any machine
- [ ] **Team Workspaces**: Share sessions across your team
- [ ] **Mobile Access**: Search archives from your phone

### Future
- [ ] **VS Code Extension**: Browse archives in your editor
- [ ] **Advanced Analytics**: Team knowledge insights
- [ ] **API Access**: Programmatic archive management

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT - see [LICENSE](LICENSE).

---

**[claudesessions.com](https://claudesessions.com)** - Never lose context again.
