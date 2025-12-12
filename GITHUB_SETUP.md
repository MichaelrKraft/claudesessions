# GitHub Repository Setup Guide

This document outlines the steps to set up the Claude Sessions GitHub repository with the open core model.

## Pre-requisites

- GitHub account
- Git installed locally
- Repository name: `claudesessions`
- Username: `michaelkraft`

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `claudesessions`
3. Description: "Never lose context again. Auto-archive and search your Claude Code sessions. Free & open source."
4. **Public** repository
5. Do NOT initialize with README (we have one)
6. Do NOT add .gitignore (we have one)
7. Do NOT add license (we have MIT LICENSE)
8. Click "Create repository"

## Step 2: Initialize Local Repository

```bash
cd ~/claudesessions

# Initialize git (if not already done)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial release: Claude Sessions v1.0.0

- Auto-archive sessions on exit via Claude Code hooks
- Full-text search with SQLite FTS5
- Manual checkpoints with /checkpoint command
- Web dashboard for browsing archives
- CLI tools for terminal users
- Complete documentation
- Open core model (free core + pro features)
- MIT licensed"

# Add remote
git remote add origin git@github.com:michaelkraft/claudesessions.git

# Push to GitHub
git push -u origin main
```

## Step 3: Repository Settings

### Topics/Tags
Add these topics to help discovery:
- `claude-code`
- `claude`
- `anthropic`
- `session-management`
- `archiving`
- `search`
- `cli`
- `developer-tools`
- `productivity`
- `open-source`

### About Section
**Description:** Never lose context again. Auto-archive and search your Claude Code sessions.

**Website:** https://claudesessions.com

### README Badges
The README.md already includes:
- License badge
- Claude Code Compatible badge

### Branch Protection (Optional, for later)
Once you have contributors:
- Require PR reviews before merging
- Require status checks to pass
- Require branches to be up to date

## Step 4: GitHub Pages (for docs)

1. Go to repository Settings → Pages
2. Source: Deploy from a branch
3. Branch: `main`
4. Folder: `/docs`
5. Save

This will make documentation available at:
`https://michaelkraft.github.io/claudesessions/`

**Alternative:** Use the landing page from `/web/landing.html` as GitHub Pages if you prefer.

## Step 5: Create Releases

### v1.0.0 Release
1. Go to Releases → Draft a new release
2. Tag: `v1.0.0`
3. Release title: "Claude Sessions v1.0.0 - Initial Release"
4. Description:

```markdown
# Claude Sessions v1.0.0 🎉

The first public release of Claude Sessions - never lose context from your Claude Code sessions again.

## Features

✅ **Auto-Archive** - Sessions automatically saved on exit
✅ **Full-Text Search** - SQLite FTS5 with BM25 ranking
✅ **Manual Checkpoints** - `/checkpoint` command for milestones
✅ **Web Dashboard** - Browse archives visually at localhost:3456
✅ **CLI Tools** - `sessions list`, `sessions search`, `sessions view`
✅ **Export** - JSON, Markdown, or plain text formats
✅ **Privacy-First** - 100% local storage, no cloud required

## Installation

```bash
curl -fsSL https://claudesessions.com/install.sh | bash
```

Or clone manually:

```bash
git clone https://github.com/michaelkraft/claudesessions.git ~/.claudesessions
~/.claudesessions/install.sh
```

## Documentation

- [Quick Start Guide](https://github.com/michaelkraft/claudesessions#quick-start)
- [Full Documentation](https://claudesessions.com/docs)
- [CLI Reference](https://github.com/michaelkraft/claudesessions/blob/main/docs/CLI-REFERENCE.md)

## What's Next

🔮 Coming in v1.1:
- AI-powered summaries (Claude API integration)
- Team sharing features
- VS Code extension

## Feedback

Found a bug? Have a feature request? Open an issue!

Want to contribute? See [CONTRIBUTING.md](./CONTRIBUTING.md)
```

5. Click "Publish release"

## Step 6: Community Files

The repository already includes:
- ✅ `README.md` - Comprehensive overview
- ✅ `LICENSE` - MIT license
- ✅ `CONTRIBUTING.md` - Contribution guidelines
- ✅ `.gitignore` - Proper exclusions

### Still Need (Optional):
- `CODE_OF_CONDUCT.md` - Community standards
- `SECURITY.md` - Security policy
- Issue templates
- PR template

## Step 7: Marketing Setup

### install.sh Hosting
The install script references `https://claudesessions.com/install.sh`

Options:
1. **GitHub Pages** - Serve from repo
2. **Render Static Site** - Free tier
3. **Netlify** - Free tier
4. **Vercel** - Free tier

Recommended: Use GitHub Pages initially:
- Put `install.sh` in `/docs/install.sh`
- Access at `https://michaelkraft.github.io/claudesessions/install.sh`

### Domain Setup
If you buy `claudesessions.com`:
1. Point to GitHub Pages or Render
2. Update DNS (see `docs/DNS-SETUP.md`)
3. Enable HTTPS
4. Update all references in code

## Repository Structure

```
claudesessions/
├── .gitignore              # Git exclusions
├── LICENSE                 # MIT license
├── README.md               # Main documentation
├── CONTRIBUTING.md         # How to contribute
├── OPEN_CORE_STRATEGY.md   # Business model docs
├── GITHUB_SETUP.md         # This file
├── install.sh              # One-line installer
├── bin/                    # CLI executables
│   ├── sessions
│   ├── archive-session.sh
│   ├── save-now.sh
│   ├── db-manager.sh
│   └── web-ui
├── commands/               # Slash commands
│   ├── checkpoint.md
│   └── archives.md
├── skills/                 # Claude skills
│   └── SKILL.md
├── docs/                   # Documentation site
│   ├── index.html
│   ├── pricing.html
│   ├── DNS-SETUP.md
│   ├── DEMO-VIDEO-SCRIPT.md
│   └── LAUNCH-POSTS.md
└── web/                    # Landing page
    ├── landing.html
    └── server.js
```

## Next Steps After Push

1. ✅ Push to GitHub
2. ✅ Add topics/tags
3. ✅ Create v1.0.0 release
4. ✅ Enable GitHub Pages
5. 📝 Post launch announcements (see `docs/LAUNCH-POSTS.md`)
6. 🎥 Record demo video (see `docs/DEMO-VIDEO-SCRIPT.md`)
7. 🌐 Set up domain (see `docs/DNS-SETUP.md`)

## Open Core Model Notes

**What's Open Source:**
- Everything in this repository (MIT license)
- Core features: archive, search, checkpoints, web UI
- CLI tools and documentation
- Community contributions welcome

**What's Pro (Coming Soon):**
- AI-powered summaries (Claude API)
- Team collaboration and sharing
- Cloud sync and backup
- VS Code extension
- Priority support

See `OPEN_CORE_STRATEGY.md` for full business model details.

---

**Ready to launch!** 🚀

Next command: `git push -u origin main`
