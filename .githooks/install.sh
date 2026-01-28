#!/bin/bash
# Install git hooks for Swarm Dominion development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(git rev-parse --show-toplevel)/.git/hooks"

echo "Installing git hooks..."

for hook in "$SCRIPT_DIR"/*; do
    hook_name=$(basename "$hook")
    if [ "$hook_name" != "install.sh" ] && [ -f "$hook" ]; then
        cp "$hook" "$HOOKS_DIR/$hook_name"
        chmod +x "$HOOKS_DIR/$hook_name"
        echo "  ✓ Installed $hook_name"
    fi
done

echo ""
echo "Git hooks installed successfully!"
