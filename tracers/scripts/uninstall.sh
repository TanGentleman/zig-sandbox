#!/usr/bin/env bash
# Uninstall tracers: remove the binary.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/TanGentleman/tracers/main/tracers/scripts/uninstall.sh | bash
#   TRACERS_INSTALL_DIR=$HOME/bin curl -fsSL ... | bash
#
# tracers has no data directory of its own. The looptap database lives at
# ~/.looptap — uninstall looptap with its own `--purge` flag if you want it gone.

set -euo pipefail

INSTALL_DIR="${TRACERS_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
BINARY="${INSTALL_DIR}/tracers"

if [[ -f "$BINARY" ]]; then
	rm "$BINARY"
	echo "Removed ${BINARY}"
else
	echo "No binary found at ${BINARY} — already gone or installed elsewhere?"
fi

if [[ -d "$HOME/.looptap" ]]; then
	echo ""
	echo "Note: looptap's database at ~/.looptap is untouched (not owned by tracers)."
fi

echo ""
echo "tracers uninstalled. To reinstall:"
echo "  curl -fsSL https://raw.githubusercontent.com/TanGentleman/tracers/main/tracers/scripts/install.sh | bash"
