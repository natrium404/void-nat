#!/bin/sh
# Usage: scripts/bootstrap.sh [dest-dir]
# Default dest: ~/void-bulid
set -eu

REPO_URL_DEFAULT="https://github.com/natrium404/void-nat.git"
UPSTREAM_URL="https://github.com/void-linux/void-packages.git"

DEST="${1:-$HOME/void-build}"
REPO_URL="${VOID_CUSTOM_REPO:-$REPO_URL_DEFAULT}"

# colors
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	R=$(printf '\033[31m') # shuck: ignore=X007
	G=$(printf '\033[32m') # shuck: ignore=X007
	Y=$(printf '\033[33m') # shuck: ignore=X007
	C=$(printf '\033[36m') # shuck: ignore=X007
	B=$(printf '\033[1m')  # shuck: ignore=X007
	N=$(printf '\033[0m')  # shuck: ignore=X007
else
	R=''
	G=''
	Y=''
	C=''
	B=''
	N=''
fi
say() { printf '%s>>>%s %s\n' "$C" "$N" "$*"; }
ok() { printf '%s ok %s %s\n' "$G" "$N" "$*"; }
warn() { printf '%swarn%s %s\n' "$Y" "$N" "$*" >&2; }
die() {
	printf '%sfail%s %s\n' "$R" "$N" "$*" >&2
	exit 1
}

command -v git >/dev/null 2>&1 || die "git not installed"
command -v xbps-install >/dev/null 2>&1 ||
	warn "xbps-install not found; install git base-devel before building"

mkdir -p "$DEST" && cd "$DEST"
say "target: $DEST"

# void-packages
if [ -d void-packages/.git ]; then
	ok "void-packages already cloned"
else
	say "cloning void-packages"
	git clone --depth=1 "$UPSTREAM_URL" void-packages || die "clone failed"
fi

cd void-packages
# guard: no accidental pushes to upstream
if ! git remote | grep -qx upstream; then
	git remote add upstream "$UPSTREAM_URL" 2>/dev/null || true
fi
git remote set-url --push origin no_push 2>/dev/null || true
git remote set-url --push upstream no_push 2>/dev/null || true
git config pull.ff only
ok "void-packages ready"

if [ -d masterdir ]; then
	ok "xbps-src already bootstrapped"
else
	say "bootstrapping xbps-src (needs root)"
	./xbps-src binary-bootstrap || die "bootstrap failed"
	ok "xbps-src bootstrapped"
fi
cd "$DEST"

# void-nat
if [ -d void-nat/.git ]; then
	ok "void-nat already cloned"
else
	say "cloning void-nat from $REPO_URL"
	git clone "$REPO_URL" void-nat || die "clone failed"
fi

chmod +x void-nat/scripts/*.sh 2>/dev/null || true

printf '\n%s ready %s\n' "$B" "$N"
printf '  build:  %s/void-nat/scripts/build.sh\n' "$DEST"
printf '  check:  %s/void-nat/scripts/check.sh\n' "$DEST"
