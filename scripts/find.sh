#!/bin/sh
# Search templates across custom (void-nat) and upstream (void-packages) repos.
#
# Usage: scripts/find.sh [-d] <pattern>

set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

SEARCH_DESC=0
case "${1:-}" in
-d | --desc)
	SEARCH_DESC=1
	shift
	;;
-h | --help)
	sed -n '2,4p' "$0"
	exit 0
	;;
esac

pattern=${1:-}
[ -n "$pattern" ] || die "usage: scripts/find.sh [-d] <pattern>"

require_void_packages

installed_pkgs=$(xbps-query -l | awk '{print $2}' | sed 's/-[^-]*$//')

is_installed() {
	printf '%s\n' "$installed_pkgs" | grep -Fxq "$1"
}

found=0

search_repo() {
	label=$1
	dir=$2
	color=$3

	[ -d "$dir" ] || return 0

	for tpl in "$dir"/*/template; do
		[ -f "$tpl" ] || continue
		pkg_dir=${tpl%/template}
		pkg=${pkg_dir##*/}

		if [ "$label" = "upstream" ] && [ -f "$CUSTOM_SRC/$pkg/template" ]; then
			continue
		fi

		desc=""

		if [ "$SEARCH_DESC" -eq 1 ]; then
			desc=$(sed -n 's/^short_desc="\(.*\)"/\1/p' "$tpl" | head -n1)
			case "$pkg $desc" in
			*"$pattern"*) ;;
			*) continue ;;
			esac
		else
			case "$pkg" in
			*"$pattern"*) ;;
			*) continue ;;
			esac
		fi

		ver=$(template_version "$tpl")
		desc=${desc:-$(sed -n 's/^short_desc="\(.*\)"/\1/p' "$tpl" | head -n1)}

		if is_installed "$pkg"; then
			badge="${C_GREEN}󰄬${C_RESET}"
		else
			badge=" "
		fi

		printf '  %s %s[%-8s]%s %-28s %-12s %s\n' \
			"$badge" "$color" "$label" "$C_RESET" "$pkg" "($ver)" "$desc"
		found=$((found + 1))
	done
}

search_repo "custom" "$CUSTOM_SRC" "$C_GREEN"
search_repo "upstream" "$PKGS_DIR/srcpkgs" "$C_BLUE"

[ "$found" -gt 0 ] || die "no packages matching '$pattern'"
