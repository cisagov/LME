#!/usr/bin/env bash
# run-all.sh — Full pipeline: generate + deploy + test for all ranges
#
# @decision DEC-RUNALL-001
# @title Single entry point for the entire test pipeline
# @status accepted
# @rationale Operators need one command to go from params.yml to test results.
#   This script runs generate → deploy → test for every range that has a
#   params.yml. Deploys run sequentially (Ludus can only deploy one range at
#   a time), tests run in parallel after all deploys complete.
#
# Usage:
#   bash scripts/run-all.sh                    # all ranges
#   bash scripts/run-all.sh ranges/fresh-23    # single range

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RANGES_DIR="$(dirname "$SCRIPT_DIR")/ranges"

# If a specific range is given, only run that one
if [ -n "${1:-}" ]; then
    RANGE_DIRS=("$1")
else
    RANGE_DIRS=()
    for d in "$RANGES_DIR"/*/; do
        [ -f "$d/params.yml" ] && RANGE_DIRS+=("$d")
    done
fi

if [ ${#RANGE_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No ranges found with params.yml"
    exit 1
fi

echo "=============================================="
echo "  LME Full Test Pipeline"
echo "  $(date -Iseconds)"
echo "  Ranges: ${#RANGE_DIRS[@]}"
echo "=============================================="

# Phase 1: Generate all range configs
echo ""
echo "=== Phase 1: Generate range configs ==="
for range_dir in "${RANGE_DIRS[@]}"; do
    bash "$SCRIPT_DIR/generate-range.sh" "$range_dir"
done

# Phase 2: Deploy all ranges (sequential — Ludus limitation)
# Continue on deploy failure so other ranges still get deployed and tested
echo ""
echo "=== Phase 2: Deploy ranges ==="
DEPLOY_FAILURES=0
for range_dir in "${RANGE_DIRS[@]}"; do
    echo ""
    if ! bash "$SCRIPT_DIR/deploy-range.sh" "$range_dir"; then
        echo "WARNING: Deploy failed for $(basename "$range_dir") — will still attempt test"
        DEPLOY_FAILURES=$((DEPLOY_FAILURES + 1))
    fi
done
[ $DEPLOY_FAILURES -gt 0 ] && echo "WARNING: $DEPLOY_FAILURES deploy(s) failed"

# Phase 3: Run tests (parallel)
echo ""
echo "=== Phase 3: Run tests ==="

PIDS=()
NAMES=()
LOGS=()

for range_dir in "${RANGE_DIRS[@]}"; do
    range_name=$(basename "$range_dir")
    log_file="$range_dir/test-run.log"
    echo ">>> Launching: $range_name (log: $log_file)"
    bash "$SCRIPT_DIR/run-test.sh" "$range_dir" > "$log_file" 2>&1 &
    PIDS+=($!)
    NAMES+=("$range_name")
    LOGS+=("$log_file")
done

echo ""
echo "Waiting for ${#PIDS[@]} test runs..."

PASS=0
FAIL=0

for i in "${!PIDS[@]}"; do
    if wait "${PIDS[$i]}"; then
        PASS=$((PASS + 1))
        echo "  ${NAMES[$i]}: PASS"
    else
        FAIL=$((FAIL + 1))
        echo "  ${NAMES[$i]}: FAIL (see ${LOGS[$i]})"
    fi
done

echo ""
echo "=============================================="
echo "  Results: $PASS pass, $FAIL fail"
echo "  $(date -Iseconds)"
echo "=============================================="

[ $FAIL -eq 0 ] || exit 1
