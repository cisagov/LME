#!/usr/bin/env bash
# generate-range.sh — Generate range-config.yml from params.yml + template
#
# @decision DEC-GENERATE-001
# @title Deterministic range generation from params.yml
# @status accepted
# @rationale range-config.yml was hand-edited with hardcoded IPs and
#   credentials, leading to stale configs and credential leaks in git.
#   This script generates range-config.yml deterministically from params.yml
#   (source of truth) and templates/range-config.yml.tpl. The only file
#   a tester edits is params.yml — everything else is generated.
#
# Usage:
#   bash scripts/generate-range.sh <range-dir>
#   bash scripts/generate-range.sh ranges/fresh-23
#
# Creates/overwrites: <range-dir>/range-config.yml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUDUS_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$LUDUS_DIR/templates/range-config.yml.tpl"
RANGE_DIR="${1:?Usage: generate-range.sh <range-dir>}"

if [ ! -f "$RANGE_DIR/params.yml" ]; then
    echo "ERROR: $RANGE_DIR/params.yml not found" >&2
    exit 1
fi

# Validate and read params
PARAMS_FILE="$RANGE_DIR/params.yml"
source "$SCRIPT_DIR/lib-params.sh"
validate_params

RANGE_NAME=$(read_param RANGE_NAME)
LME_BRANCH=$(read_param LME_BRANCH "develop")
LME_BRANCH_COMMIT=$(read_param LME_BRANCH_COMMIT "")
LME_VERSION=$(read_param LME_VERSION "2.3.0")
LME_REPO_URL=$(read_param LME_REPO_URL "https://github.com/cisagov/LME.git")
UPGRADE_FROM_BRANCH=$(read_param UPGRADE_FROM_BRANCH "")

# Determine offline mode from range name
OFFLINE_ROLE_VAR=""
if echo "$RANGE_NAME" | grep -qi offline; then
    OFFLINE_ROLE_VAR="      ludus_lme_server_offline: true"
fi

# For upgrade ranges, use the UPGRADE_FROM branch for initial deploy
if [ -n "$UPGRADE_FROM_BRANCH" ]; then
    DEPLOY_BRANCH="$UPGRADE_FROM_BRANCH"
    DEPLOY_VERSION=$(read_param UPGRADE_FROM_VERSION "2.2.0")
    DEPLOY_COMMIT=$(read_param UPGRADE_FROM_COMMIT "")
    DEPLOY_REPO="$LME_REPO_URL"
else
    DEPLOY_BRANCH="$LME_BRANCH"
    DEPLOY_VERSION="$LME_VERSION"
    DEPLOY_COMMIT="$LME_BRANCH_COMMIT"
    DEPLOY_REPO="$LME_REPO_URL"
fi

# git_ref: use commit if specified, otherwise branch name
GIT_REF="${DEPLOY_COMMIT:-$DEPLOY_BRANCH}"

# If LME_REPO_URL is a local directory, the VM can't clone it.
# Use the default GitHub URL for the Ludus deploy; deploy-range.sh
# will rsync the local code to the server after deploy.
if echo "$DEPLOY_REPO" | grep -qE '^/'; then
    # Local path — VM can't clone it. Use GitHub for initial Ludus deploy,
    # deploy-range.sh will rsync the local code afterward.
    RANGE_REPO_URL="https://github.com/cisagov/LME.git"
    # For upgrades, keep the UPGRADE_FROM branch (it exists on GitHub).
    # For fresh/offline, use 'develop' — local branch may not exist on GitHub.
    # deploy-range.sh rsyncs the actual local code after Ludus deploy.
    if [ -n "$UPGRADE_FROM_BRANCH" ]; then
        GIT_REF="$DEPLOY_BRANCH"
    else
        GIT_REF="develop"
    fi
    echo "Generating range-config.yml for: $RANGE_NAME" >&2
    echo "  Local repo: $DEPLOY_REPO (will be synced by deploy-range.sh)" >&2
    echo "  Range config uses: $RANGE_REPO_URL @ $GIT_REF (for initial Ludus clone)" >&2
else
    RANGE_REPO_URL="$DEPLOY_REPO"
    echo "Generating range-config.yml for: $RANGE_NAME" >&2
    echo "  Repo: $RANGE_REPO_URL" >&2
fi
echo "  Git ref: $GIT_REF (branch=$DEPLOY_BRANCH, commit=${DEPLOY_COMMIT:-auto})" >&2
echo "  Version: $DEPLOY_VERSION" >&2
if [ -n "$UPGRADE_FROM_BRANCH" ]; then
    echo "  Upgrade to: $LME_BRANCH ($LME_VERSION) @ ${LME_BRANCH_COMMIT:-HEAD}" >&2
fi
if [ -n "$OFFLINE_ROLE_VAR" ]; then
    echo "  Offline mode: enabled" >&2
fi

# Generate from template using sed substitution
# The template uses {{ VAR }} for our vars and {{ range_id }} for Ludus Jinja
sed \
    -e "s|{{ RANGE_NAME }}|$RANGE_NAME|g" \
    -e "s|{{ LME_VERSION }}|$DEPLOY_VERSION|g" \
    -e "s|{{ GIT_REF }}|$GIT_REF|g" \
    -e "s|{{ REPO_URL }}|$RANGE_REPO_URL|g" \
    -e "s|{{ OFFLINE_ROLE_VAR }}|$OFFLINE_ROLE_VAR|g" \
    "$TEMPLATE" > "$RANGE_DIR/range-config.yml"

# Clean up empty OFFLINE_ROLE_VAR line if not set
if [ -z "$OFFLINE_ROLE_VAR" ]; then
    sed -i '/^$/d; /^[[:space:]]*$/N; /^\n$/d' "$RANGE_DIR/range-config.yml"
fi

echo "  Wrote: $RANGE_DIR/range-config.yml" >&2
