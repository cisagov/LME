#!/bin/bash
# DEPRECATED: This script is deprecated. Please use uninstall_lme.sh instead.
# This script is kept for backwards compatibility but will be removed in a future version.

echo "WARNING: wipe_lme.sh is deprecated!"
echo "Please use the new uninstall_lme.sh script instead:"
echo ""
echo "  sudo ./scripts/uninstall_lme.sh"
echo ""
echo "The new script provides:"
echo "  • Better error handling"
echo "  • Confirmation prompts"
echo "  • Detailed progress reporting"
echo "  • Complete cleanup of all LME components"
echo ""
read -p "Do you want to run the new uninstall script now? (y/n): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    exec sudo "$SCRIPT_DIR/uninstall_lme.sh"
else
    echo "Uninstall cancelled."
    exit 0
fi