#!/bin/sh
# Sync, build custom packages
#
# Usage: scripts/build.sh [pkg...]
set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

require_void_packages
require_xbps_src

# sync first (skip pull if XBPS_CUSTOM_NO_PULL=1)
if [ "${XBPS_CUSTOM_NO_PULL:-0}" -eq 1 ]; then
	"$CUSTOM_ROOT/scripts/sync.sh" --no-pull
else
	"$CUSTOM_ROOT/scripts/sync.sh"
fi

pkgs=${*:-$(list_custom_pkgs)}
[ -n "$pkgs" ] || die "no packages to build"

# build
built=""
built_fail=0
for pkg in $pkgs; do
	tpl="$PKGS_DIR/srcpkgs/$pkg/template"
	if [ ! -f "$tpl" ]; then
		warn "skipping $pkg: no template at $tpl"
		continue
	fi

	info "building $pkg"
	if (cd "$PKGS_DIR" && ./xbps-src pkg "$pkg"); then
		ok "$pkg built"
		built="$built $pkg"
	else
		err "$pkg FAILED"
		built_fail=1
	fi
done

[ -n "$built" ] || die "nothing built"

# index repos that actually contain .xbps files
info "indexing local repos"
for sub in "" nonfree multilib debug; do
	d="$HOSTDIR/binpkgs/$sub"
	[ -d "$d" ] || continue
	ls "$d"/*.xbps >/dev/null 2>&1 || continue
	xbps-rindex -a "$d"/*.xbps >/dev/null 2>&1 || warn "rindex failed on $d"
done

# group built pkgs
pkgs_free=""
pkgs_nonfree=""
pkgs_multilib=""
pkgs_debug=""

for pkg in $built; do
	placed=0
	for sub in "" nonfree multilib debug; do
		d="$HOSTDIR/binpkgs/$sub"
		[ -d "$d" ] || continue
		if ls "$d/${pkg}-"*.xbps >/dev/null 2>&1; then
			case "$sub" in
			"") pkgs_free="$pkgs_free $pkg" ;;
			nonfree) pkgs_nonfree="$pkgs_nonfree $pkg" ;;
			multilib) pkgs_multilib="$pkgs_multilib $pkg" ;;
			debug) pkgs_debug="$pkgs_debug $pkg" ;;
			esac
			placed=1
			break
		fi
	done
	[ "$placed" -eq 0 ] && warn "no .xbps found for $pkg"
done

# print install commands
printf '\n%s install / update:%s\n\n' "$C_BOLD" "$C_RESET"

if [ -n "$pkgs_free" ]; then
	printf '  sudo xbps-install -R %s -u%s\n\n' \
		"$HOSTDIR/binpkgs" "$pkgs_free"
fi

if [ -n "$pkgs_nonfree" ]; then
	printf '  sudo xbps-install -R %s/nonfree -u%s\n\n' \
		"$HOSTDIR/binpkgs" "$pkgs_nonfree"
fi

if [ -n "$pkgs_multilib" ]; then
	printf '  sudo xbps-install -R %s/multilib -u%s\n\n' \
		"$HOSTDIR/binpkgs" "$pkgs_multilib"
fi

if [ -n "$pkgs_debug" ]; then
	printf '  sudo xbps-install -R %s/debug -u%s\n\n' \
		"$HOSTDIR/binpkgs" "$pkgs_debug"
fi

[ "$built_fail" -eq 1 ] && exit 1 || exit 0
