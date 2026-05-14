#!/usr/bin/env bash
# run-test.sh — Execute parameterized test notebook for a Ludus range
#
# Usage:
#   bash run-test.sh <range-dir>
#   bash run-test.sh ranges/fresh-23-install
#
# The range-dir must contain:
#   params.yml     — papermill parameters
#   range-config.yml — Ludus range configuration
#   CREDENTIALS.md — access credentials
#
# Output:
#   <range-dir>/executed-test.ipynb  — notebook with results
#   <range-dir>/executed-test.pdf    — compiled PDF report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUDUS_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$LUDUS_DIR/templates/testing-evidence-template.ipynb"
RANGE_DIR="${1:?Usage: run-test.sh <range-dir>}"

if [ ! -f "$RANGE_DIR/params.yml" ]; then
    echo "ERROR: $RANGE_DIR/params.yml not found"
    exit 1
fi

echo "=== Running test for: $RANGE_DIR ==="
echo "Template: $TEMPLATE"
echo "Parameters: $RANGE_DIR/params.yml"

# Run papermill
uvx papermill "$TEMPLATE" "$RANGE_DIR/executed-test.ipynb" \
    -f "$RANGE_DIR/params.yml" \
    --request-save-on-cell-execute \
    2>&1

echo "=== Converting to PDF ==="
uvx --from nbconvert jupyter-nbconvert --to latex "$RANGE_DIR/executed-test.ipynb" 2>&1 | tail -2

# Add TOC
python3 -c "
with open('$RANGE_DIR/executed-test.tex', 'r') as f:
    tex = f.read()
tex = tex.replace(r'\begin{document}', r'''\\usepackage{bookmark}
\\setcounter{tocdepth}{3}
\\begin{document}
\\tableofcontents
\\newpage
''')
with open('$RANGE_DIR/executed-test.tex', 'w') as f:
    f.write(tex)
"

cd "$RANGE_DIR"
xelatex -interaction=nonstopmode executed-test.tex 2>&1 | tail -2
xelatex -interaction=nonstopmode executed-test.tex 2>&1 | tail -2

# Cleanup latex artifacts
rm -f executed-test.tex executed-test.aux executed-test.log executed-test.out executed-test.toc

echo "=== Done ==="
echo "Notebook: $RANGE_DIR/executed-test.ipynb"
echo "PDF:      $RANGE_DIR/executed-test.pdf"
