#!/usr/bin/env bash
# Thin wrapper — implementation: ../lib/backup_restore_workflow.sh
set -euo pipefail
_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB="$(cd "$_HERE/../lib" && pwd)/backup_restore_workflow.sh"
export LME_WORKFLOW_SCRIPT_NAME="$0"
exec "$_LIB" "$_HERE" "$@"
