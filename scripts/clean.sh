#!/bin/sh
# Remove custom overlay from void-packages so `git pull` is clean.
#
# Usage: scripts/clean.sh [--quiet]
set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

[ -d "$PKGS_DIR/.git" ] || exit 0

log() { [ "$QUIET" -eq 0 ] && info "$*" || true; }

log "reverting tracked files (srcpkgs, common/shlibs)"
git -C "$PKGS_DIR" checkout -- srcpkgs common/shlibs 2>/dev/null || true

log "removing untracked custom package dirs"
if [ -d "$CUSTOM_SRC" ]; then
	for d in "$CUSTOM_SRC"/*/; do
		[ -d "$d" ] || continue
		pkg=$(basename "$d")
		target="$PKGS_DIR/srcpkgs/$pkg"
		[ -d "$target" ] || continue
		if git -C "$PKGS_DIR" ls-files --error-unmatch "srcpkgs/$pkg" \
			>/dev/null 2>&1; then
			: # tracked → already reverted above
		else
			rm -rf "$target"
		fi
	done
fi

log "cleaning stray untracked files in srcpkgs"
git -C "$PKGS_DIR" clean -fd srcpkgs >/dev/null 2>&1 || true

log "clean"
