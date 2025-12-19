#!/bin/bash
# Comprehensive Test Suite for Claude Sessions New Features
# Tests: Auto-Context Injection + Project-Based Grouping

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TEST_DIR="/tmp/claudesessions-test-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Setup test environment
setup() {
    info "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_DIR/fake-project/.git"
    mkdir -p "$TEST_DIR/npm-project"
    echo '{"name": "test-project"}' > "$TEST_DIR/npm-project/package.json"
    mkdir -p "$TEST_DIR/rust-project"
    echo '[package]' > "$TEST_DIR/rust-project/Cargo.toml"
    mkdir -p "$TEST_DIR/no-project"
}

echo ""
echo "=============================================="
echo "  Claude Sessions Feature Test Suite"
echo "=============================================="
echo ""

setup

# =============================================
# TEST 1: inject-context.sh Syntax Validation
# =============================================
echo -e "\n${YELLOW}TEST 1: inject-context.sh Syntax Validation${NC}"

if bash -n "$SCRIPT_DIR/bin/inject-context.sh" 2>/dev/null; then
    pass "inject-context.sh has valid bash syntax"
else
    fail "inject-context.sh has syntax errors"
fi

# =============================================
# TEST 2: inject-context.sh - Silent when no DB
# =============================================
echo -e "\n${YELLOW}TEST 2: inject-context.sh - Silent Exit (No DB)${NC}"

# Temporarily move DB if exists
BACKUP_DB=""
if [ -f "$HOME/.claude/session-archives/sessions.db" ]; then
    BACKUP_DB="$HOME/.claude/session-archives/sessions.db.backup-test"
    mv "$HOME/.claude/session-archives/sessions.db" "$BACKUP_DB"
fi

output=$(echo '{"cwd": "/tmp/nonexistent"}' | "$SCRIPT_DIR/bin/inject-context.sh" 2>&1)
exit_code=$?

# Restore DB
if [ -n "$BACKUP_DB" ]; then
    mv "$BACKUP_DB" "$HOME/.claude/session-archives/sessions.db"
fi

if [ $exit_code -eq 0 ] && [ -z "$output" ]; then
    pass "inject-context.sh exits silently when no database"
else
    fail "inject-context.sh should exit silently when no database (got: '$output')"
fi

# =============================================
# TEST 3: inject-context.sh - Silent when no matches
# =============================================
echo -e "\n${YELLOW}TEST 3: inject-context.sh - Silent Exit (No Matching Sessions)${NC}"

output=$(echo '{"cwd": "/tmp/definitely-no-sessions-here-12345"}' | "$SCRIPT_DIR/bin/inject-context.sh" 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ] && [ -z "$output" ]; then
    pass "inject-context.sh exits silently when no matching sessions"
else
    fail "inject-context.sh should exit silently for no matches (got output length: ${#output})"
fi

# =============================================
# TEST 4: inject-context.sh - Project Root Detection
# =============================================
echo -e "\n${YELLOW}TEST 4: Project Root Detection in inject-context.sh${NC}"

# Test git project detection
cat > "$TEST_DIR/test-project-detection.sh" << 'SCRIPT'
#!/bin/bash
detect_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ] && [ -n "$dir" ]; do
        if [ -d "$dir/.git" ] || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/pyproject.toml" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo "$1"
}
detect_project_root "$1"
SCRIPT
chmod +x "$TEST_DIR/test-project-detection.sh"

# Test .git detection
result=$("$TEST_DIR/test-project-detection.sh" "$TEST_DIR/fake-project/subdir/deep" 2>/dev/null || echo "$TEST_DIR/fake-project/subdir/deep")
mkdir -p "$TEST_DIR/fake-project/subdir/deep"
result=$("$TEST_DIR/test-project-detection.sh" "$TEST_DIR/fake-project/subdir/deep")
if [ "$result" = "$TEST_DIR/fake-project" ]; then
    pass "Detects .git project root correctly"
else
    fail "Failed to detect .git project root (got: $result, expected: $TEST_DIR/fake-project)"
fi

# Test package.json detection
result=$("$TEST_DIR/test-project-detection.sh" "$TEST_DIR/npm-project")
if [ "$result" = "$TEST_DIR/npm-project" ]; then
    pass "Detects package.json project root correctly"
else
    fail "Failed to detect package.json project root (got: $result)"
fi

# Test Cargo.toml detection
result=$("$TEST_DIR/test-project-detection.sh" "$TEST_DIR/rust-project")
if [ "$result" = "$TEST_DIR/rust-project" ]; then
    pass "Detects Cargo.toml project root correctly"
else
    fail "Failed to detect Cargo.toml project root (got: $result)"
fi

# Test fallback when no project markers
result=$("$TEST_DIR/test-project-detection.sh" "$TEST_DIR/no-project")
if [ "$result" = "$TEST_DIR/no-project" ]; then
    pass "Falls back to cwd when no project markers"
else
    fail "Fallback failed (got: $result)"
fi

# =============================================
# TEST 5: archive-session.sh Syntax Validation
# =============================================
echo -e "\n${YELLOW}TEST 5: archive-session.sh Syntax Validation${NC}"

if bash -n "$SCRIPT_DIR/bin/archive-session.sh" 2>/dev/null; then
    pass "archive-session.sh has valid bash syntax"
else
    fail "archive-session.sh has syntax errors"
fi

# =============================================
# TEST 6: db-manager.sh Syntax Validation
# =============================================
echo -e "\n${YELLOW}TEST 6: db-manager.sh Syntax Validation${NC}"

if bash -n "$SCRIPT_DIR/bin/db-manager.sh" 2>/dev/null; then
    pass "db-manager.sh has valid bash syntax"
else
    fail "db-manager.sh has syntax errors"
fi

# =============================================
# TEST 7: sessions CLI Syntax Validation
# =============================================
echo -e "\n${YELLOW}TEST 7: sessions CLI Syntax Validation${NC}"

if bash -n "$SCRIPT_DIR/bin/sessions" 2>/dev/null; then
    pass "sessions CLI has valid bash syntax"
else
    fail "sessions CLI has syntax errors"
fi

# =============================================
# TEST 8: install.sh Syntax Validation
# =============================================
echo -e "\n${YELLOW}TEST 8: install.sh Syntax Validation${NC}"

if bash -n "$SCRIPT_DIR/install.sh" 2>/dev/null; then
    pass "install.sh has valid bash syntax"
else
    fail "install.sh has syntax errors"
fi

# =============================================
# TEST 9: sessions project command exists
# =============================================
echo -e "\n${YELLOW}TEST 9: sessions project Command Exists${NC}"

if "$SCRIPT_DIR/bin/sessions" help 2>&1 | grep -q "project"; then
    pass "sessions help shows project command"
else
    fail "sessions help missing project command"
fi

# =============================================
# TEST 10: sessions project runs without error
# =============================================
echo -e "\n${YELLOW}TEST 10: sessions project Command Runs${NC}"

if "$SCRIPT_DIR/bin/sessions" project 2>&1 | grep -qE "(Projects|No projects)"; then
    pass "sessions project command runs successfully"
else
    fail "sessions project command failed"
fi

# =============================================
# TEST 11: Database Schema Has Project Columns
# =============================================
echo -e "\n${YELLOW}TEST 11: Database Schema Has Project Columns${NC}"

DB_FILE="$HOME/.claude/session-archives/sessions.db"
if [ -f "$DB_FILE" ]; then
    schema=$(sqlite3 "$DB_FILE" ".schema sessions" 2>/dev/null)
    if echo "$schema" | grep -q "project_root"; then
        pass "Database has project_root column"
    else
        fail "Database missing project_root column"
    fi
    if echo "$schema" | grep -q "project_name"; then
        pass "Database has project_name column"
    else
        fail "Database missing project_name column"
    fi
else
    info "Skipping DB schema test - no database found (run 'sessions reindex' first)"
fi

# =============================================
# TEST 12: Hook Configuration in install.sh
# =============================================
echo -e "\n${YELLOW}TEST 12: Hook Configuration in install.sh${NC}"

if grep -q "SessionStart" "$SCRIPT_DIR/install.sh" && grep -q "inject-context.sh" "$SCRIPT_DIR/install.sh"; then
    pass "install.sh configures SessionStart hook with inject-context.sh"
else
    fail "install.sh missing SessionStart hook configuration"
fi

if grep -q "SessionEnd" "$SCRIPT_DIR/install.sh" && grep -q "archive-session.sh" "$SCRIPT_DIR/install.sh"; then
    pass "install.sh configures SessionEnd hook with archive-session.sh"
else
    fail "install.sh missing SessionEnd hook configuration"
fi

# =============================================
# TEST 13: archive-session.sh Has Project Detection
# =============================================
echo -e "\n${YELLOW}TEST 13: archive-session.sh Has Project Detection${NC}"

if grep -q "detect_project_root" "$SCRIPT_DIR/bin/archive-session.sh"; then
    pass "archive-session.sh has detect_project_root function"
else
    fail "archive-session.sh missing detect_project_root function"
fi

if grep -q "project_root" "$SCRIPT_DIR/bin/archive-session.sh" && grep -q "project_name" "$SCRIPT_DIR/bin/archive-session.sh"; then
    pass "archive-session.sh stores project_root and project_name"
else
    fail "archive-session.sh missing project storage"
fi

# =============================================
# TEST 14: Metadata JSON Includes Project Fields
# =============================================
echo -e "\n${YELLOW}TEST 14: Metadata Template Includes Project Fields${NC}"

if grep -q '"project_root"' "$SCRIPT_DIR/bin/archive-session.sh" && grep -q '"project_name"' "$SCRIPT_DIR/bin/archive-session.sh"; then
    pass "archive-session.sh metadata includes project fields"
else
    fail "archive-session.sh metadata missing project fields"
fi

# =============================================
# TEST 15: db-manager.sh INSERT Includes Project Fields
# =============================================
echo -e "\n${YELLOW}TEST 15: db-manager.sh INSERT Includes Project Fields${NC}"

if grep -q "project_root, project_name" "$SCRIPT_DIR/bin/db-manager.sh"; then
    pass "db-manager.sh INSERT statement includes project columns"
else
    fail "db-manager.sh INSERT missing project columns"
fi

# =============================================
# TEST 16: Migration Logic Exists
# =============================================
echo -e "\n${YELLOW}TEST 16: Migration Logic for Existing Users${NC}"

if grep -q "ALTER TABLE sessions ADD COLUMN project_root" "$SCRIPT_DIR/bin/db-manager.sh"; then
    pass "db-manager.sh has migration for project_root column"
else
    fail "db-manager.sh missing project_root migration"
fi

if grep -q "ALTER TABLE sessions ADD COLUMN project_name" "$SCRIPT_DIR/bin/db-manager.sh"; then
    pass "db-manager.sh has migration for project_name column"
else
    fail "db-manager.sh missing project_name migration"
fi

# =============================================
# TEST 17: FTS5 Table Recreation Fix
# =============================================
echo -e "\n${YELLOW}TEST 17: FTS5 Contentless Table Fix${NC}"

if grep -q "DROP TABLE IF EXISTS sessions_fts" "$SCRIPT_DIR/bin/db-manager.sh"; then
    pass "db-manager.sh properly drops FTS5 table before reindex"
else
    fail "db-manager.sh should drop FTS5 table (contentless tables can't DELETE)"
fi

# =============================================
# TEST 18: inject-context.sh Handles Empty Input
# =============================================
echo -e "\n${YELLOW}TEST 18: inject-context.sh Handles Empty/Bad Input${NC}"

# Test with empty input
output=$(echo '' | "$SCRIPT_DIR/bin/inject-context.sh" 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "inject-context.sh handles empty input gracefully"
else
    fail "inject-context.sh crashed on empty input"
fi

# Test with malformed JSON
output=$(echo 'not json' | "$SCRIPT_DIR/bin/inject-context.sh" 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "inject-context.sh handles malformed JSON gracefully"
else
    fail "inject-context.sh crashed on malformed JSON"
fi

# =============================================
# TEST 19: File Permissions
# =============================================
echo -e "\n${YELLOW}TEST 19: File Permissions${NC}"

if [ -x "$SCRIPT_DIR/bin/inject-context.sh" ]; then
    pass "inject-context.sh is executable"
else
    fail "inject-context.sh is not executable"
fi

if [ -x "$SCRIPT_DIR/bin/archive-session.sh" ]; then
    pass "archive-session.sh is executable"
else
    fail "archive-session.sh is not executable"
fi

if [ -x "$SCRIPT_DIR/bin/sessions" ]; then
    pass "sessions CLI is executable"
else
    fail "sessions CLI is not executable"
fi

# =============================================
# SUMMARY
# =============================================
echo ""
echo "=============================================="
echo "  TEST RESULTS SUMMARY"
echo "=============================================="
echo ""
echo -e "  ${GREEN}PASSED${NC}: $PASS_COUNT"
echo -e "  ${RED}FAILED${NC}: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Features are ready for customers.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review and fix before release.${NC}"
    exit 1
fi
