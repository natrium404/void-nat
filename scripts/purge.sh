#!/bin/sh
# Remove stale build artifacts, sources, and binpkgs.
#
# Usage:
#   scripts/purge.sh binpkgs [pkg...]   # remove built packages
#   scripts/purge.sh sources [pkg...]   # remove downloaded source tarballs
#   scripts/purge.sh masterdir          # wipe build chroot
#   scripts/purge.sh syscache           # sudo xbps-remove -O -o
#   scripts/purge.sh all                # binpkgs + sources + masterdir
#   scripts/purge.sh --dry-run ...      # preview, don't delete

set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

require_void_packages

DRY=0
if [ "${1:-}" = "--dry-run" ]; then
	DRY=1
	shift
fi

ACTION="${1:-}"
[ -n "$ACTION" ] || die "usage: purge.sh [--dry-run] {binpkgs|sources|masterdir|syscache|all} [pkg...]"
shift || true

BINPKGS="$HOSTDIR/binpkgs"
SOURCES="$HOSTDIR/sources"
MASTERDIR="$PKGS_DIR/masterdir"

# rm wrapper honoring dry-run
_rm() {
	if [ "$DRY" -eq 1 ]; then
		printf '  would rm: %s\n' "$*"
	else
		rm -rf -- "$@"
	fi
}

# find built artifacts for a pkg across all subrepos
_find_binpkgs() {
	pkg="$1"
	find "$BINPKGS" -maxdepth 2 -type f \
		\( -name "${pkg}-*.xbps" -o -name "${pkg}-*.xbps.sig*" \) 2>/dev/null
}

# find source tarballs matching pkg name
_find_sources() {
	pkg="$1"
	find "$SOURCES" -maxdepth 2 -type f -name "${pkg}-*" 2>/dev/null
}

purge_binpkgs() {
	pkgs="$*"
	if [ -z "$pkgs" ]; then
		pkgs=$(list_custom_pkgs)
		[ -n "$pkgs" ] || {
			warn "no custom packages"
			return 0
		}
	fi
	for pkg in $pkgs; do
		files=$(_find_binpkgs "$pkg")
		if [ -z "$files" ]; then
			printf '  %s[keep]%s  %s - no binpkgs\n' "$C_BLUE" "$C_RESET" "$pkg"
			continue
		fi
		printf '  %s[purge]%s %s\n' "$C_YELLOW" "$C_RESET" "$pkg"
		printf '%s\n' "$files" | while IFS= read -r f; do
			[ -n "$f" ] && _rm "$f"
		done
	done
	# repodata becomes stale; regenerate on next build automatically,
	# but drop it now to avoid xbps-install seeing ghost versions
	if [ -d "$BINPKGS" ] && [ "$DRY" -eq 0 ]; then
		info "removing repodata (regenerated on next build)"
		rm -rf "$BINPKGS"/*/repodata 2>/dev/null || true
	fi
}

purge_sources() {
	pkgs="$*"
	if [ -z "$pkgs" ]; then
		pkgs=$(list_custom_pkgs)
		[ -n "$pkgs" ] || return 0
	fi
	for pkg in $pkgs; do
		files=$(_find_sources "$pkg")
		[ -z "$files" ] && continue
		printf '  %s[purge]%s sources for %s\n' "$C_YELLOW" "$C_RESET" "$pkg"
		printf '%s\n' "$files" | while IFS= read -r f; do
			[ -n "$f" ] && _rm "$f"
		done
	done
}

purge_masterdir() {
	found=0
	for d in "$PKGS_DIR"/masterdir "$PKGS_DIR"/masterdir-*; do
		[ -d "$d" ] || continue
		info "removing $d (next build will be from scratch)"
		_rm "$d"
		found=1
	done
	[ "$found" -eq 1 ] || warn "no masterdir at $PKGS_DIR"
}

purge_syscache() {
	info "system xbps cache: sudo xbps-remove -O -o"
	if [ "$DRY" -eq 1 ]; then
		printf '  would run: sudo xbps-remove -O -o\n'
		return
	fi
	sudo xbps-remove -O -o
}

case "$ACTION" in
binpkgs) purge_binpkgs "$@" ;;
sources) purge_sources "$@" ;;
masterdir) purge_masterdir ;;
syscache) purge_syscache ;;
all)
	purge_binpkgs "$@"
	purge_sources "$@"
	purge_masterdir
	;;
-h | --help)
	sed -n '2,12p' "$0"
	exit 0
	;;
*) die "unknown action: $ACTION" ;;
esac

[ "$DRY" -eq 1 ] && warn "dry run - nothing actually deleted"
ok "purge done"
