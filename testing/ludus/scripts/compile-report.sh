#!/usr/bin/env bash
# compile-report.sh — Convert executed notebook → report.md + report.pdf
# Uses podman pandoc container if available, falls back to local pandoc
set -euo pipefail

RANGE_DIR="${1:?Usage: compile-report.sh <range-dir>}"
RANGE_NAME=$(basename "$RANGE_DIR")

if [ ! -f "$RANGE_DIR/executed-test.ipynb" ]; then
    echo "ERROR: $RANGE_DIR/executed-test.ipynb not found. Run run-test.sh first."
    exit 1
fi

echo "=== Generating report for $RANGE_NAME ==="

# Extract notebook to report.md
python3 -c "
import json

with open('$RANGE_DIR/executed-test.ipynb') as f:
    nb = json.load(f)

params_text = ''
if __import__('os').path.exists('$RANGE_DIR/params.yml'):
    with open('$RANGE_DIR/params.yml') as f:
        params_text = f.read()

md = []
md.append('---')
md.append('title: \"LME Test Report — $RANGE_NAME\"')
md.append('date: \"$(date +%Y-%m-%d)\"')
md.append('geometry: margin=1in')
md.append('toc: true')
md.append('numbersections: true')
md.append('header-includes:')
md.append('  - \\\\usepackage{booktabs}')
md.append('---')
md.append('')
if params_text:
    md.append('# Test Parameters')
    md.append('')
    md.append('\`\`\`yaml')
    md.append(params_text)
    md.append('\`\`\`')
    md.append('')

for cell in nb.get('cells', []):
    if cell['cell_type'] == 'markdown':
        md.append(cell['source'])
        md.append('')
    elif cell['cell_type'] == 'code':
        md.append('\`\`\`python')
        md.append(cell['source'])
        md.append('\`\`\`')
        md.append('')
        for out in cell.get('outputs', []):
            if 'text' in out:
                md.append('\`\`\`')
                text = out['text'] if isinstance(out['text'], str) else ''.join(out['text'])
                md.append(text.rstrip())
                md.append('\`\`\`')
                md.append('')

with open('$RANGE_DIR/report.md', 'w') as f:
    f.write('\n'.join(md))
print(f'report.md: {len(md)} lines')
"

# Compile to PDF — try podman pandoc container first, fallback to local
PANDOC_ARGS="report.md -o report.pdf --pdf-engine=xelatex --toc --number-sections \
    -V colorlinks=true -V linkcolor=blue -V urlcolor=blue \
    -V geometry:margin=1in -V fontsize=11pt \
    -V mainfont=DejaVu\ Sans -V monofont=DejaVu\ Sans\ Mono"

cd "$RANGE_DIR"

if command -v podman >/dev/null 2>&1; then
    echo "Using podman pandoc container..."
    podman run --rm -v "$(pwd):/data:Z" -w /data \
        docker.io/pandoc/extra:latest $PANDOC_ARGS 2>&1
elif command -v pandoc >/dev/null 2>&1; then
    echo "Using local pandoc..."
    pandoc $PANDOC_ARGS 2>&1
else
    echo "ERROR: Neither podman nor pandoc found. Install one of:"
    echo "  podman: see https://podman.io/getting-started/installation"
    echo "  pandoc: apt install pandoc texlive-xetex texlive-fonts-recommended fonts-dejavu"
    exit 1
fi

echo "=== Done ==="
echo "  report.md:  $RANGE_DIR/report.md"
echo "  report.pdf: $RANGE_DIR/report.pdf"
