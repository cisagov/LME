#!/usr/bin/env bash
# rsync_watch.sh – watch a directory tree and rsync changed files while
# ignoring every dot‑file and dot‑directory (e.g. .venv, .git, .env).

set -euo pipefail

# ----------------------------------------------------------------------
# Configuration – edit these values to match your environment
# ----------------------------------------------------------------------
REMOTE=${REMOTE:?Please set the REMOTE environment variable}   # destination for rsyn
echo $REMOTE

# ----------------------------------------------------------------------
# Determine the project root using Git
# ----------------------------------------------------------------------
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
echo "$PROJECT_ROOT"

# Move to the project root so that the filter file can be found easily.
cd "$PROJECT_ROOT"

# Ensure the filter file exists; it contains the dot‑file exclusion rules.
if [[ ! -f .rsync-filter ]]; then
  echo "Error: .rsync-filter not found in $PROJECT_ROOT" >&2
  exit 1
fi

# ----------------------------------------------------------------------
# Start watching.  -0   → NUL‑delimited output (safe for any filename)
#               -r   → watch recursively
#               -e   → exclude any path component beginning with a dot
# ----------------------------------------------------------------------
fswatch -0 -r -e '(^|/)\..*' . |
while IFS= read -r -d '' file; do
  # Extra safety: ignore any path that contains a hidden component.
  if [[ "$file" == *"/."* ]]; then
    continue
  fi
  # Compute the path relative to PROJECT_ROOT, stripping the root path.
  rel="${file#$PROJECT_ROOT/}"
  # Ensure the relative path does not start with a leading slash.
  rel="${rel#/}"
  # Sync the changed file, preserving the directory hierarchy.
  echo $file "->" $REMOTE$rel
  rsync -avz --filter='dir-merge /.rsync-filter' "$file" "${REMOTE}${rel}"

  #Notify the user when the file has been transferred.
  # On macOS we can use `osascript` to display a notification.
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"Synced $rel\" with title \"rsync\""
  else
    # Fallback: simple terminal message.
    echo "Synced $rel"
  fi
  # Emit a terminal beep (ASCII BEL). Most terminal emulators will produce a ding.
  printf '\a'
done
