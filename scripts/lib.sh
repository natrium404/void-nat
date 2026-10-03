#!/bin/sh
# Shared helpers, do not execute.

# paths
# Resolve repo root regardless of cwd or symlink invocation.
_custom_root() {
	CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P # shuck: ignore=C024
}

CUSTOM_ROOT="$(_custom_root)"
VOID_ROOT="$(dirname "$CUSTOM_ROOT")"
PKGS_DIR="$VOID_ROOT/void-packages"
CUSTOM_SRC="$CUSTOM_ROOT/srcpkgs"
CUSTOM_COMMON="$CUSTOM_ROOT/common"
SHLIBS_APPEND="$CUSTOM_COMMON/shlibs.append" # shuck: ignore=C001
HOSTDIR="$PKGS_DIR/hostdir"                  # shuck: ignore=C001

# allow nonfree/restricted packages
export XBPS_ALLOW_RESTRICTED=yes

# colors
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_RED=$(printf '\033[31m')
	C_GREEN=$(printf '\033[32m')
	C_YELLOW=$(printf '\033[33m')
	C_BLUE=$(printf '\033[34m')
	C_CYAN=$(printf '\033[36m')
	C_BOLD=$(printf '\033[1m')
	C_RESET=$(printf '\033[0m')
else
	C_RED=''
	C_GREEN=''
	C_YELLOW=''
	C_BLUE='' # shuck: ignore=C001
	C_CYAN=''
	C_BOLD='' # shuck: ignore=C001
	C_RESET=''
fi

# logging
info() { printf '%s>>>%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok() { printf '%s ok %s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err() { printf '%sfail%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() {
	err "$*"
	exit 1
}

# guards
require_void_packages() {
	[ -d "$PKGS_DIR/.git" ] || die "missing $PKGS_DIR (run scripts/bootstrap.sh)"
}

require_xbps_src() {
	[ -x "$PKGS_DIR/xbps-src" ] || die "missing $PKGS_DIR/xbps-src"
	# xbps-src uses masterdir-<arch> by default; accept either form.
	set -- "$PKGS_DIR"/masterdir "$PKGS_DIR"/masterdir-*
	found=0
	for d in "$@"; do
		[ -d "$d" ] && found=1 && break
	done
	[ "$found" -eq 1 ] ||
		die "xbps-src not bootstrapped (cd $PKGS_DIR && ./xbps-src binary-bootstrap)"
}

require_clean_worktree_or_warn() {
	# Used before git pull; overlay dirties the tree.
	if ! git -C "$PKGS_DIR" diff --quiet -- srcpkgs common/shlibs 2>/dev/null; then
		warn "void-packages has local changes; cleaning before pull"
		"$CUSTOM_ROOT/scripts/clean.sh" --quiet
	fi
}

# version helpers
# Print 'version=' value from a template, empty if missing.
template_version() {
	[ -f "$1" ] || {
		printf ''
		return
	}
	sed -n 's/^version=//p' "$1" | head -n1
}

# exit 0 if $1 > $2 (version-sort aware)
ver_gt() {
	[ "$1" = "$2" ] && return 1
	[ -z "$1" ] && return 1
	[ -z "$2" ] && return 0
	printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1 | grep -qx -- "$1"
}

# exit 0 if $1 == $2
ver_eq() { [ "$1" = "$2" ]; }

# listing
# Iterate custom packages. Usage: list_custom_pkgs | while read pkg; do ...
list_custom_pkgs() {
	[ -d "$CUSTOM_SRC" ] || return 0
	for d in "$CUSTOM_SRC"/*/; do
		[ -d "$d" ] || continue
		printf '%s\n' "$(basename "$d")"
	done
}
