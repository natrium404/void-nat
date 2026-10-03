#!/bin/sh
# Pull upstream master, then overlay custom templates onto void-packages.
# Refuses to overwrite when upstream's version is newer.
#
# Usage: scripts/sync.sh [--no-pull] [--dry-run]

set -eu

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh" # shuck: ignore=C003, C024

NO_PULL=0
DRY=0
for arg in "$@"; do
	case "$arg" in
	--no-pull) NO_PULL=1 ;;
	--dry-run) DRY=1 ;;
	-h | --help)
		sed -n '2,5p' "$0"
		exit 0
		;;
	*) die "unknown arg: $arg" ;;
	esac
done

require_void_packages

# pull upstream
if [ "$NO_PULL" -eq 0 ]; then
	info "pulling upstream master"
	require_clean_worktree_or_warn
	if ! git -C "$PKGS_DIR" pull --ff-only origin master >/dev/null 2>&1 &&
		! git -C "$PKGS_DIR" pull --ff-only upstream master >/dev/null 2>&1; then
		die "git pull failed in $PKGS_DIR (check remotes: upstream? origin?)"
	fi
	ok "upstream up to date"
fi

# overlay
info "checking custom packages against upstream"
overlayed=0
skipped=0
identical=0
unique=0

pkgs=$(list_custom_pkgs)
[ -n "$pkgs" ] || {
	warn "no custom packages in $CUSTOM_SRC"
	exit 0
}

printf '%s\n' "$pkgs" | while IFS= read -r pkg; do
	mine="$CUSTOM_SRC/$pkg/template"
	theirs="$PKGS_DIR/srcpkgs/$pkg/template"

	[ -f "$mine" ] || {
		warn "  [skip]     $pkg - no template in custom"
		continue
	}

	vmine=$(template_version "$mine")

	if [ ! -f "$theirs" ]; then
		printf '  %s[new]%s      %s (%s) - not in upstream\n' \
			"$C_GREEN" "$C_RESET" "$pkg" "$vmine"
		[ "$DRY" -eq 0 ] && cp -rT "$CUSTOM_SRC/$pkg" "$PKGS_DIR/srcpkgs/$pkg"
		unique=$((unique + 1))
		continue
	fi

	vtheirs=$(template_version "$theirs")

	if ver_eq "$vmine" "$vtheirs"; then
		printf '  %s[same]%s     %s (%s) - identical version\n' \
			"$C_BLUE" "$C_RESET" "$pkg" "$vmine"
		[ "$DRY" -eq 0 ] && cp -rT "$CUSTOM_SRC/$pkg" "$PKGS_DIR/srcpkgs/$pkg"
		identical=$((identical + 1))
	elif ver_gt "$vmine" "$vtheirs"; then
		printf '  %s[newer]%s    %s (%s > %s) - overlaying\n' \
			"$C_GREEN" "$C_RESET" "$pkg" "$vmine" "$vtheirs"
		[ "$DRY" -eq 0 ] && cp -rT "$CUSTOM_SRC/$pkg" "$PKGS_DIR/srcpkgs/$pkg"
		overlayed=$((overlayed + 1))
	elif ver_gt "$vtheirs" "$vmine"; then
		printf '  %s[STALE]%s    %s (%s < %s) - SKIPPED\n' \
			"$C_YELLOW" "$C_RESET" "$pkg" "$vmine" "$vtheirs"
		printf '             upstream is newer; run scripts/check.sh %s\n' "$pkg"
		skipped=$((skipped + 1))
	else
		printf '  %s[?]%s        %s (mine=%s theirs=%s) - overlaying anyway\n' \
			"$C_YELLOW" "$C_RESET" "$pkg" "$vmine" "$vtheirs"
		[ "$DRY" -eq 0 ] && cp -rT "$CUSTOM_SRC/$pkg" "$PKGS_DIR/srcpkgs/$pkg"
		overlayed=$((overlayed + 1))
	fi
done

# shlibs
if [ -s "$SHLIBS_APPEND" ]; then
	info "merging shlibs additions"
	if [ "$DRY" -eq 0 ]; then
		cat "$SHLIBS_APPEND" >>"$PKGS_DIR/common/shlibs"
		sort -u "$PKGS_DIR/common/shlibs" -o "$PKGS_DIR/common/shlibs"
	fi
fi

[ "$DRY" -eq 1 ] && warn "dry run - nothing written"
ok "sync complete"
