# Contributing to Claude Sessions

Thank you for your interest in contributing to Claude Sessions! This document provides guidelines for contributing.

## Code of Conduct

Be respectful and constructive. We're all here to make Claude Code better.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template
3. Include:
   - Your OS and version
   - Claude Code version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs

### Suggesting Features

1. Check existing feature requests
2. Describe the use case, not just the solution
3. Explain why this benefits Claude Code users

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push and open a PR

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/claudesessions.git
cd claudesessions

# Test installation
./install.sh

# Run tests
./test.sh
```

## Code Style

### Shell Scripts
- Use `#!/bin/bash` shebang
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals
- Add comments for complex logic
- Test with `shellcheck`

### Python Scripts
- Python 3.8+ compatible
- Use type hints
- Follow PEP 8
- Document functions with docstrings

### Commit Messages
- Use present tense: "Add feature" not "Added feature"
- Keep first line under 50 characters
- Reference issues: "Fix #123"

## Testing

Before submitting:

1. **Fresh install test**: Remove `~/.claudesessions` and reinstall
2. **Archive test**: Create a checkpoint and verify it saves
3. **Search test**: Verify FTS search works
4. **Hook test**: Exit Claude Code and verify auto-archive

## Project Structure

```
claudesessions/
├── bin/                  # Core executables
│   ├── archive-session.sh   # Main archiver
│   ├── db-manager.sh        # SQLite management
│   ├── save-now.sh          # Manual checkpoint
│   └── sessions             # CLI tool
├── commands/             # Claude Code slash commands
├── skills/               # Claude Skills files
│   ├── SKILL.md             # Skill definition
│   └── scripts/             # Skill scripts
├── web/                  # Web dashboard
├── install.sh            # Installation script
└── README.md
```

## Areas Needing Help

- **Documentation**: Improve guides and examples
- **Testing**: Add automated tests
- **Features**: See roadmap in README
- **Performance**: Optimize for large archives
- **UI**: Improve web dashboard

## Questions?

Open a discussion on GitHub or check existing issues.

Thank you for contributing!
