#!/bin/sh
# Report status of each custom package vs upstream.
#
# Usage: scripts/check.sh [pkg...]     # omit pkgs to check all
set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

require_void_packages

# fetch upstream refs without merging
git -C "$PKGS_DIR" fetch --quiet upstream master 2>/dev/null ||
	git -C "$PKGS_DIR" fetch --quiet origin master 2>/dev/null || true

pkgs=${*:-$(list_custom_pkgs)}
[ -n "$pkgs" ] || {
	warn "no custom packages"
	exit 0
}

for pkg in $pkgs; do
	mine="$CUSTOM_SRC/$pkg/template"
	theirs="$PKGS_DIR/srcpkgs/$pkg/template"

	[ -f "$mine" ] || {
		warn "$pkg: missing $mine"
		continue
	}

	vmine=$(template_version "$mine")

	if [ ! -f "$theirs" ]; then
		printf '%s[unique]%s    %s %s\n' "$C_GREEN" "$C_RESET" "$pkg" "$vmine"
		continue
	fi

	vtheirs=$(template_version "$theirs")

	if diff -q "$mine" "$theirs" >/dev/null 2>&1; then
		printf '%s[identical]%s %s %s (drop from void-custom?)\n' \
			"$C_BLUE" "$C_RESET" "$pkg" "$vmine"
	elif ver_gt "$vtheirs" "$vmine"; then
		printf '%s[stale]%s     %s (mine=%s upstream=%s)\n' \
			"$C_YELLOW" "$C_RESET" "$pkg" "$vmine" "$vtheirs"
		printf '  --- template diff ---\n'
		diff -u "$mine" "$theirs" | sed 's/^/  /' | head -n40 || true
	else
		printf '%s[differs]%s   %s (mine=%s upstream=%s)\n' \
			"$C_CYAN" "$C_RESET" "$pkg" "$vmine" "$vtheirs"
		printf '  --- template diff ---\n'
		diff -u "$theirs" "$mine" | sed 's/^/  /' | head -n40 || true
	fi
done
