#!/bin/bash
#
# Claude Sessions - Credit Management
# https://claudesessions.com
#
# Functions for managing session restoration credits
#

# Credit file location
CREDITS_FILE="$HOME/.claudesessions/credits.json"
CREDITS_DIR="$HOME/.claudesessions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure credits directory exists
ensure_credits_dir() {
    [[ ! -d "$CREDITS_DIR" ]] && mkdir -p "$CREDITS_DIR"
}

# Get current credit balance
get_credits() {
    if [[ -f "$CREDITS_FILE" ]]; then
        local credits=$(jq -r '.credits // 0' "$CREDITS_FILE" 2>/dev/null)
        echo "${credits:-0}"
    else
        echo "0"
    fi
}

# Check if user has credits
has_credits() {
    local credits=$(get_credits)
    [[ $credits -gt 0 ]]
}

# Use one credit (returns 0 on success, 1 if no credits)
use_credit() {
    local credits=$(get_credits)

    if [[ $credits -le 0 ]]; then
        return 1
    fi

    # Decrement credit
    local new_credits=$((credits - 1))
    jq --argjson c "$new_credits" '.credits = $c' "$CREDITS_FILE" > "$CREDITS_FILE.tmp" && \
        mv "$CREDITS_FILE.tmp" "$CREDITS_FILE"

    echo "$new_credits"
    return 0
}

# Show credit status after restore
show_credit_status() {
    local credits=$(get_credits)

    if [[ $credits -le 0 ]]; then
        echo -e "${RED}No credits remaining${NC}"
        echo -e "Get more → ${CYAN}https://claudesessions.com/buy${NC}"
    elif [[ $credits -le 3 ]]; then
        echo -e "${YELLOW}Credits remaining: $credits${NC}"
        echo -e "Running low! → ${CYAN}https://claudesessions.com/buy${NC}"
    else
        echo -e "${GREEN}Credits remaining: $credits${NC}"
    fi
}

# Show purchase prompt (when user has no credits)
show_purchase_prompt() {
    local session_count=${1:-0}

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Session restoration: 50 cents per restore${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Pick up any saved session where you left off,           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  no matter how old the session is.                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}Get 20 restores for \$10${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  → ${CYAN}https://claudesessions.com/buy${NC}                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  Already have a key? Run:                                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}    ${GREEN}sessions activate <key>${NC}                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Activate a license key (adds 20 credits)
activate_key() {
    local key="$1"

    # Validate key format: cs_ followed by 20-30 alphanumeric chars
    if [[ ! "$key" =~ ^cs_[a-zA-Z0-9]{20,30}$ ]]; then
        echo -e "${RED}Invalid key format.${NC}"
        echo "Keys should look like: cs_Xk9mP2nQ4rT6vW8yZ1a2B3c4"
        return 1
    fi

    ensure_credits_dir

    if [[ -f "$CREDITS_FILE" ]]; then
        # Add to existing credits
        local current=$(get_credits)
        local new_total=$((current + 20))

        jq --argjson c "$new_total" --arg k "$key" \
            '.credits = $c | .key = $k | .last_activated = now | .activations += 1' \
            "$CREDITS_FILE" > "$CREDITS_FILE.tmp" && \
            mv "$CREDITS_FILE.tmp" "$CREDITS_FILE"

        echo ""
        echo -e "${GREEN}+20 credits added!${NC}"
        echo -e "Total credits: ${CYAN}$new_total${NC}"
        echo ""
    else
        # Create new credits file
        local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        cat > "$CREDITS_FILE" << EOF
{
  "credits": 20,
  "key": "$key",
  "created": "$now",
  "last_activated": "$now",
  "activations": 1
}
EOF
        chmod 600 "$CREDITS_FILE"

        echo ""
        echo -e "${GREEN}20 credits activated!${NC}"
        echo ""
        echo "You can now restore any session:"
        echo -e "  ${CYAN}sessions continue <session-name>${NC}"
        echo ""
    fi

    return 0
}

# Check credits and show prompt if needed (gate function)
# Returns 0 if user has credits, 1 if not
check_credits_for_restore() {
    if has_credits; then
        return 0
    else
        show_purchase_prompt
        return 1
    fi
}

# Perform credit check, use credit, and show status
# Call this when actually performing a restore
perform_restore_with_credit() {
    if ! has_credits; then
        show_purchase_prompt
        return 1
    fi

    # Use the credit
    local remaining=$(use_credit)

    if [[ $? -eq 0 ]]; then
        # Success - show remaining after restore completes
        # (caller should show this after restore is done)
        echo "$remaining"
        return 0
    else
        show_purchase_prompt
        return 1
    fi
}

# Show current credit balance
show_credits() {
    local credits=$(get_credits)

    echo ""
    if [[ $credits -le 0 ]]; then
        echo -e "Credits: ${RED}0${NC}"
        echo ""
        echo "Get 20 restores for \$10"
        echo -e "→ ${CYAN}https://claudesessions.com/buy${NC}"
    else
        echo -e "Credits: ${GREEN}$credits${NC}"
        if [[ $credits -le 3 ]]; then
            echo ""
            echo -e "${YELLOW}Running low!${NC} Get more at:"
            echo -e "→ ${CYAN}https://claudesessions.com/buy${NC}"
        fi
    fi
    echo ""
}
