#!/usr/bin/env bash
# Uninstall tracers.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/TanGentleman/tracers/main/tracers/scripts/uninstall.sh | bash
#   TRACERS_INSTALL_DIR=$HOME/bin curl -fsSL ... | bash
#
# Only removes the `tracers` binary. Does not touch the looptap database at
# ~/.looptap/ — that's looptap's data, delete it yourself if you want it gone.

set -euo pipefail

# Honor the same override install.sh uses, then fall back to common locations.
candidates=()
if [[ -n "${TRACERS_INSTALL_DIR:-}" ]]; then
	candidates+=("${TRACERS_INSTALL_DIR}/tracers")
fi
if [[ -n "${XDG_BIN_HOME:-}" ]]; then
	candidates+=("${XDG_BIN_HOME}/tracers")
fi
candidates+=("${HOME}/.local/bin/tracers")
candidates+=("${HOME}/bin/tracers")
candidates+=("/usr/local/bin/tracers")

if found_in_path="$(command -v tracers 2>/dev/null)"; then
	candidates+=("$found_in_path")
fi

removed=0
seen=""
for path in "${candidates[@]}"; do
	# Dedupe by realpath so a symlink + its target aren't both reported.
	resolved="$path"
	if command -v readlink >/dev/null 2>&1; then
		resolved="$(readlink -f "$path" 2>/dev/null || echo "$path")"
	fi
	case ":${seen}:" in
	*":${resolved}:"*) continue ;;
	esac
	seen="${seen}:${resolved}"

	if [[ -e "$path" ]] || [[ -L "$path" ]]; then
		rm -f "$path"
		echo "Removed ${path}" >&2
		removed=$((removed + 1))
	fi
done

if [[ "$removed" -eq 0 ]]; then
	echo "tracers not found in any known location — nothing to remove." >&2
	exit 0
fi

if [[ -d "${HOME}/.looptap" ]]; then
	echo "" >&2
	echo "Note: looptap's database at ${HOME}/.looptap is untouched." >&2
	echo "      Delete it manually if you want a full clean: rm -rf ${HOME}/.looptap" >&2
fi
