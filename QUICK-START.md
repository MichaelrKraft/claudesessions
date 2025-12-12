# Quick Start Guide

Get backwards.dev running in under 2 minutes.

## 1. Install

```bash
curl -fsSL https://backwards.dev/install.sh | bash
```

**What this does:**
- Copies files to `~/.backwards-dev/`
- Initializes the SQLite database
- Adds the SessionEnd hook to Claude Code
- Adds `sessions` command to your PATH

## 2. Verify Installation

```bash
sessions stats
```

You should see:
```
SESSION ARCHIVE STATISTICS
==========================

**Total Sessions:** 0
**Storage Used:** 0B
**Indexed:** 0 sessions
```

## 3. Create Your First Archive

Start a Claude Code session, do some work, then exit. The session will be automatically archived.

Or manually save a checkpoint:

```
/checkpoint my-first-checkpoint
```

## 4. Search Your Archives

```bash
sessions search "checkpoint"
```

## 5. Continue a Session

Next time you start Claude Code, just say:

> "Continue from my-first-checkpoint"

Claude will automatically load the key context from that session.

---

## Common Commands

| Command | Description |
|---------|-------------|
| `sessions list` | Show all archived sessions |
| `sessions search "term"` | Full-text search |
| `sessions view <name>` | View session details |
| `sessions stats` | Show archive statistics |
| `sessions web` | Open web dashboard |
| `/checkpoint <tag>` | Save current session (in Claude Code) |

## Troubleshooting

### "sessions: command not found"

Add to your shell config:
```bash
export PATH="$HOME/.backwards-dev:$PATH"
```

### Sessions not auto-archiving

Check that the hook is configured:
```bash
cat ~/.claude/settings.json | grep -A5 "SessionEnd"
```

### Database errors

Reinitialize:
```bash
~/.backwards-dev/db-manager.sh init
~/.backwards-dev/db-manager.sh reindex
```

---

Need more help? See the full [README](README.md) or [open an issue](https://github.com/yourusername/backwards-dev/issues).
