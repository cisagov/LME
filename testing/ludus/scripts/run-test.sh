#!/usr/bin/env bash
# run-test.sh — Resolve IPs from Ludus API, then execute parameterized test notebook
#
# @decision DEC-RUNTEST-002
# @title Ludus API resolves IPs at runtime — params.yml only has test identity
# @status accepted
# @rationale IPs are assigned by Ludus at deploy time based on range_second_octet
#   and ip_last_octet. Hardcoding them in params.yml couples tests to a specific
#   deployment. run-test.sh queries the Ludus API for the RANGE_NAME, resolves
#   VM IPs by hostname pattern (lme-server, win11, ubuntu, caldera), and passes
#   them as extra papermill parameters. params.yml stays minimal: just test
#   identity (name, branch, version, ssh creds, notes).
#
# Usage:
#   bash run-test.sh <range-dir>
#   bash run-test.sh ranges/fresh-23

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUDUS_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$LUDUS_DIR/templates/testing-evidence-template.ipynb"
RANGE_DIR="${1:?Usage: run-test.sh <range-dir>}"

if [ ! -f "$RANGE_DIR/params.yml" ]; then
    echo "ERROR: $RANGE_DIR/params.yml not found"
    exit 1
fi

# Validate and read params
PARAMS_FILE="$RANGE_DIR/params.yml"
source "$SCRIPT_DIR/lib-params.sh"
validate_params

RANGE_NAME=$(read_param RANGE_NAME)

echo "=== Running test for: $RANGE_DIR ==="
echo "Range name: $RANGE_NAME"
echo "Template: $TEMPLATE"

# ── Resolve IPs from Ludus CLI ───────────────────────────────────────────────
EXTRA_PARAMS=""

if command -v ludus >/dev/null 2>&1; then
    echo "Resolving IPs from Ludus CLI for range '$RANGE_NAME'..."

    VMS_JSON=$(ludus_cmd -r "$RANGE_NAME" range list --json 2>/dev/null || echo "")

    if [ -n "$VMS_JSON" ]; then
        RESOLVED=$(python3 -c "
import json, sys
data = json.loads('''$VMS_JSON''')
vms = data.get('VMs', []) if isinstance(data, dict) else (data[0].get('VMs', []) if isinstance(data, list) and data else [])
ips = {}
for vm in vms:
    name = vm.get('name', '').lower()
    ip = vm.get('ip', '')
    if not ip or vm.get('isRouter'): continue
    if 'lme' in name and ('server' in name or name.endswith('-lme')):
        ips['LME_IP'] = ip
    elif 'win11' in name:
        ips['WIN11_IP'] = ip
    elif 'ubuntu' in name:
        ips['UBUNTU_IP'] = ip
    elif 'caldera' in name and 'server' in name:
        ips['CALDERA_IP'] = ip
for k, v in ips.items():
    print(f'{k}={v}')
" 2>/dev/null)

        echo "  Resolved:"
        while IFS='=' read -r key val; do
            [ -z "$key" ] && continue
            echo "    $key=$val"
            EXTRA_PARAMS="$EXTRA_PARAMS -p $key $val"
        done <<< "$RESOLVED"
    else
        echo "  WARNING: ludus range list returned empty for '$RANGE_NAME'"
    fi
else
    echo "  WARNING: ludus CLI not found — IPs must be in params.yml"
fi

# Check if OFFLINE range — set OFFLINE_IP = LME_IP
if echo "$RANGE_NAME" | grep -qi offline; then
    LME_IP_VAL=$(echo "$EXTRA_PARAMS" | grep -oP '(?<=-p LME_IP )\S+' || true)
    if [ -n "$LME_IP_VAL" ]; then
        EXTRA_PARAMS="$EXTRA_PARAMS -p OFFLINE_IP $LME_IP_VAL"
        echo "    OFFLINE_IP=$LME_IP_VAL (auto: offline range)"
    fi
fi

echo ""

# ── Run papermill ────────────────────────────────────────────────────────────
echo "=== Running notebook ==="
uvx --with ipykernel papermill "$TEMPLATE" "$RANGE_DIR/executed-test.ipynb" \
    -f "$RANGE_DIR/params.yml" \
    $EXTRA_PARAMS \
    --request-save-on-cell-execute \
    2>&1

# ── Convert to PDF ───────────────────────────────────────────────────────────
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
