#!/bin/bash
#
# Claude Sessions - Installation Script
# https://claudesessions.com
#
# This script installs Claude Sessions for automatic session archiving.
#
# Usage:
#   curl -fsSL https://claudesessions.com/install.sh | bash
#
# Or:
#   git clone https://github.com/michaelcraft/claudesessions.git ~/.claudesessions
#   ~/.claudesessions/install.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="$HOME/.claudesessions"
CLAUDE_DIR="$HOME/.claude"
ARCHIVE_DIR="$CLAUDE_DIR/session-archives"

print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}           ${GREEN}Claude Sessions${NC} - Installation              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}           Never lose context again.                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

check_dependencies() {
    print_step "Checking dependencies..."

    local missing=()

    # Check for required commands
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v sqlite3 &> /dev/null; then
        missing+=("sqlite3")
    fi

    if ! command -v node &> /dev/null; then
        missing+=("node")
    fi

    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Please install the missing dependencies:"

        # Detect OS and provide install instructions
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install ${missing[*]}"
        elif [[ -f /etc/debian_version ]]; then
            echo "  sudo apt-get install ${missing[*]}"
        elif [[ -f /etc/redhat-release ]]; then
            echo "  sudo yum install ${missing[*]}"
        else
            echo "  Use your package manager to install: ${missing[*]}"
        fi
        echo ""
        exit 1
    fi

    print_success "All dependencies found"
}

check_claude_code() {
    print_step "Checking for Claude Code..."

    if [ ! -d "$CLAUDE_DIR" ]; then
        print_warning "Claude Code directory not found at $CLAUDE_DIR"
        print_step "Creating Claude Code directory..."
        mkdir -p "$CLAUDE_DIR"
    fi

    print_success "Claude Code directory ready"
}

install_files() {
    print_step "Installing Claude Sessions..."

    # If running from curl, we need to clone first
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/bin/sessions" ]; then
        if command -v git &> /dev/null; then
            print_step "Cloning repository..."
            rm -rf "$INSTALL_DIR" 2>/dev/null || true
            git clone --quiet https://github.com/michaelcraft/claudesessions.git "$INSTALL_DIR"
        else
            print_error "Git is required for installation"
            echo "Please install git and try again, or clone manually:"
            echo "  git clone https://github.com/michaelcraft/claudesessions.git ~/.claudesessions"
            exit 1
        fi
    fi

    # Ensure all scripts are executable
    chmod +x "$INSTALL_DIR/bin/"*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bin/sessions" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bin/web-ui" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/skills/scripts/"*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/skills/scripts/"*.py 2>/dev/null || true

    print_success "Files installed to $INSTALL_DIR"
}

setup_archive_directory() {
    print_step "Setting up archive directory..."

    mkdir -p "$ARCHIVE_DIR"

    print_success "Archive directory ready at $ARCHIVE_DIR"
}

initialize_database() {
    print_step "Initializing database..."

    "$INSTALL_DIR/bin/db-manager.sh" init 2>/dev/null || true

    print_success "Database initialized"
}

install_claude_commands() {
    print_step "Installing Claude Code commands..."

    mkdir -p "$CLAUDE_DIR/commands"

    # Copy commands
    cp "$INSTALL_DIR/commands/checkpoint.md" "$CLAUDE_DIR/commands/" 2>/dev/null || true
    cp "$INSTALL_DIR/commands/archives.md" "$CLAUDE_DIR/commands/" 2>/dev/null || true

    print_success "Commands installed (/checkpoint, /archives)"
}

install_claude_skill() {
    print_step "Installing Claude Code skill..."

    mkdir -p "$CLAUDE_DIR/skills/session-archiver/scripts"

    # Copy skill files
    cp "$INSTALL_DIR/skills/SKILL.md" "$CLAUDE_DIR/skills/session-archiver/" 2>/dev/null || true
    cp "$INSTALL_DIR/skills/"*.md "$CLAUDE_DIR/skills/session-archiver/" 2>/dev/null || true
    cp "$INSTALL_DIR/skills/scripts/"* "$CLAUDE_DIR/skills/session-archiver/scripts/" 2>/dev/null || true

    # Ensure scripts are executable
    chmod +x "$CLAUDE_DIR/skills/session-archiver/scripts/"* 2>/dev/null || true

    print_success "Skill installed (auto-activates for session continuations)"
}

configure_session_hook() {
    print_step "Configuring auto-archive hook..."

    SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    # Create settings.json if it doesn't exist
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Check if hook already exists
    if grep -q "archive-session.sh" "$SETTINGS_FILE" 2>/dev/null; then
        print_success "Session hook already configured"
        return
    fi

    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup" 2>/dev/null || true

    # Add the hook using jq
    if command -v jq &> /dev/null; then
        local hook_config='{
            "hooks": {
                "SessionEnd": [{
                    "type": "command",
                    "command": "'"$INSTALL_DIR"'/bin/archive-session.sh",
                    "timeout": 30
                }]
            }
        }'

        # Merge with existing settings
        jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$hook_config") > "$SETTINGS_FILE.tmp" && \
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

        print_success "Auto-archive hook configured"
    else
        print_warning "Could not auto-configure hook (jq not available)"
        echo "Please add this to $SETTINGS_FILE manually:"
        echo '  "hooks": { "SessionEnd": [{ "type": "command", "command": "~/.claudesessions/bin/archive-session.sh" }] }'
    fi
}

setup_path() {
    print_step "Setting up PATH..."

    # Detect shell config file
    local shell_config=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
        shell_config="$HOME/.bashrc"
    elif [ -f "$HOME/.profile" ]; then
        shell_config="$HOME/.profile"
    fi

    local path_line="export PATH=\"\$HOME/.claudesessions/bin:\$PATH\""

    if [ -n "$shell_config" ]; then
        # Check if already in PATH config
        if ! grep -q "claudesessions/bin" "$shell_config" 2>/dev/null; then
            echo "" >> "$shell_config"
            echo "# Claude Sessions" >> "$shell_config"
            echo "$path_line" >> "$shell_config"
            print_success "Added to PATH in $shell_config"
        else
            print_success "PATH already configured"
        fi
    else
        print_warning "Could not detect shell config file"
        echo "Please add this to your shell config manually:"
        echo "  $path_line"
    fi

    # Also export for current session
    export PATH="$HOME/.claudesessions/bin:$PATH"
}

verify_installation() {
    print_step "Verifying installation..."

    local errors=0

    # Check files exist
    if [ ! -f "$INSTALL_DIR/bin/sessions" ]; then
        print_error "sessions CLI not found"
        errors=$((errors + 1))
    fi

    if [ ! -f "$INSTALL_DIR/bin/archive-session.sh" ]; then
        print_error "archive-session.sh not found"
        errors=$((errors + 1))
    fi

    if [ ! -f "$CLAUDE_DIR/commands/checkpoint.md" ]; then
        print_error "checkpoint command not installed"
        errors=$((errors + 1))
    fi

    # Try running sessions
    if ! "$INSTALL_DIR/bin/sessions" stats &>/dev/null; then
        print_warning "sessions command test failed (may need shell restart)"
    fi

    if [ $errors -eq 0 ]; then
        print_success "Installation verified"
        return 0
    else
        return 1
    fi
}

print_complete() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}            Installation Complete!                     ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Restart your terminal (or run: source ~/.zshrc)"
    echo ""
    echo "  2. Start Claude Code and try:"
    echo "     /checkpoint my-first-save"
    echo ""
    echo "  3. View your archives:"
    echo "     sessions list"
    echo ""
    echo "  4. Sessions are auto-archived when you exit Claude Code"
    echo ""
    echo -e "Documentation: ${BLUE}https://claudesessions.com${NC}"
    echo -e "Issues: ${BLUE}https://github.com/michaelcraft/claudesessions/issues${NC}"
    echo ""
}

# Main installation flow
main() {
    print_banner

    check_dependencies
    check_claude_code
    install_files
    setup_archive_directory
    initialize_database
    install_claude_commands
    install_claude_skill
    configure_session_hook
    setup_path

    if verify_installation; then
        print_complete
    else
        echo ""
        print_error "Installation completed with errors. Please check the messages above."
        exit 1
    fi
}

# Run main
main "$@"
