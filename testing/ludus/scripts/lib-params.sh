#!/usr/bin/env bash
# lib-params.sh — Shared params.yml reader and validator
# Source this from other scripts: source "$SCRIPT_DIR/lib-params.sh"

# Auto-export LUDUS_API_KEY from ~/.ludus/config if not already set
if [ -z "${LUDUS_API_KEY:-}" ] && [ -f "$HOME/.ludus/config" ]; then
    _key=$(grep '^api_key' "$HOME/.ludus/config" 2>/dev/null | head -1 | awk '{print $3}')
    [ -n "$_key" ] && export LUDUS_API_KEY="$_key"
fi
if [ -z "${LUDUS_URL:-}" ] && [ -f "$HOME/.ludus/config" ]; then
    _url=$(grep '^url' "$HOME/.ludus/config" 2>/dev/null | head -1 | awk '{print $3}')
    [ -n "$_url" ] && export LUDUS_URL="$_url"
fi

# Ludus CLI wrapper — auto-adds --url if LUDUS_URL is set
ludus_cmd() {
    if [ -n "${LUDUS_URL:-}" ]; then
        ludus --url "$LUDUS_URL" "$@"
    else
        ludus "$@"
    fi
}

# Read a param from params.yml. Usage: read_param <key> [default]
read_param() {
    local key="$1" default="${2:-}"
    local val
    val=$(grep -E "^${key}:" "$PARAMS_FILE" | head -1 | sed 's/^[^:]*: *"\?\([^"]*\)"\?$/\1/')
    echo "${val:-$default}"
}

# Validate required params exist and are non-empty. Exits on failure.
validate_params() {
    local missing=()
    local required=("RANGE_NAME" "LME_BRANCH" "LME_BRANCH_COMMIT" "LME_VERSION" "SSH_USER" "SSH_PASS")

    for key in "${required[@]}"; do
        local val
        val=$(read_param "$key")
        if [ -z "$val" ]; then
            missing+=("$key")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: params.yml is missing required fields: ${missing[*]}" >&2
        echo "" >&2
        echo "Required fields:" >&2
        echo "  RANGE_NAME:       Ludus range ID (must match ludus range list)" >&2
        echo "  LME_BRANCH:       Git branch deployed on the server" >&2
        echo "  LME_BRANCH_COMMIT: Commit SHA being tested" >&2
        echo "  LME_VERSION:      Expected LME version (e.g., 2.3.0)" >&2
        echo "  SSH_USER:          SSH username for all VMs" >&2
        echo "  SSH_PASS:          SSH password" >&2
        exit 1
    fi
}
