#!/usr/bin/env bash
# run-all-tests.sh — Execute tests for all ranges in parallel
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RANGES_DIR="$(dirname "$SCRIPT_DIR")/ranges"

echo "=============================================="
echo "  LME Ludus Test Suite (parallel)"
echo "  $(date -Iseconds)"
echo "=============================================="

PIDS=()
NAMES=()
LOGS=()

for range_dir in "$RANGES_DIR"/*/; do
    range_name=$(basename "$range_dir")
    if [ ! -f "$range_dir/params.yml" ]; then
        echo "SKIP: $range_name (no params.yml)"
        continue
    fi

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
echo "=============================================="
