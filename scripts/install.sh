#!/bin/sh
# Build (if needed) and install packages from void-nat or upstream void-packages.
#
# Usage: scripts/install.sh [--no-build] <pkg...>

set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

NO_BUILD=0
while [ $# -gt 0 ]; do
	case "$1" in
	--no-build)
		NO_BUILD=1
		shift
		;;
	-h | --help)
		sed -n '2,4p' "$0"
		exit 0
		;;
	*) break ;;
	esac
done

[ $# -gt 0 ] || die "usage: scripts/install.sh [--no-build] <pkg...>"

require_void_packages
require_xbps_src

custom_pkgs=""
upstream_pkgs=""

for pkg in "$@"; do
	if [ -f "$CUSTOM_SRC/$pkg/template" ]; then
		custom_pkgs="$custom_pkgs $pkg"
	elif [ -f "$PKGS_DIR/srcpkgs/$pkg/template" ]; then
		upstream_pkgs="$upstream_pkgs $pkg"
	else
		die "package '$pkg' not found in $CUSTOM_SRC or $PKGS_DIR/srcpkgs"
	fi
done

if [ "$NO_BUILD" -eq 0 ]; then
	if [ -n "$custom_pkgs" ]; then
		# shellcheck disable=SC2086
		"$CUSTOM_ROOT/scripts/build.sh" $custom_pkgs
	fi

	for pkg in $upstream_pkgs; do
		info "building upstream $pkg"
		(cd "$PKGS_DIR" && ./xbps-src pkg "$pkg") || die "failed to build $pkg"
		ok "$pkg built"
	done

	info "indexing local repos"
	for sub in "" nonfree multilib debug; do
		d="$HOSTDIR/binpkgs/$sub"
		[ -d "$d" ] || continue
		ls "$d"/*.xbps >/dev/null 2>&1 || continue
		xbps-rindex -a "$d"/*.xbps >/dev/null 2>&1 || warn "rindex failed on $d"
	done
fi

repo_args=""
for sub in "" nonfree multilib debug; do
	d="$HOSTDIR/binpkgs/$sub"
	[ -d "$d" ] && repo_args="$repo_args --repository=$d"
done

info "installing:$custom_pkgs$upstream_pkgs"
# shellcheck disable=SC2086
sudo xbps-install $repo_args -u $custom_pkgs $upstream_pkgs
