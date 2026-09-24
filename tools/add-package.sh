#!/bin/sh
# add-package.sh <name> <version> <tarball-or-directory>
#   - tarball: copied into the repo as <name>-<version>.tar.gz
#   - directory: packed (including its meta/ tree) into the tarball
# Then rebuild + sign the index.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/repo.env"

[ $# -eq 3 ] || { echo "usage: $0 <name> <version> <tarball|dir>" >&2; exit 2; }
name=$1; ver=$2; src=$3

echo "$name" | grep -Eq '^[a-z0-9][a-z0-9+._-]*$' \
  || { echo "bad package name: $name (use [a-z0-9][a-z0-9+._-]*)" >&2; exit 2; }

pdir="$REPO_DIR/packages/$name"
mkdir -p "$pdir"
dest="$pdir/$name-$ver.tar.gz"

if [ -d "$src" ]; then
  tmp=$(mktemp -d)
  cp -a "$src"/. "$tmp/"
  ( cd "$tmp" && tar -czf "$dest" . )
  rm -rf "$tmp"
elif [ -f "$src" ]; then
  cp "$src" "$dest"
else
  echo "no such file or directory: $src" >&2
  exit 2
fi

# Lift (or create) the machine-readable deps.txt next to the tarball so the
# index builder can read it without unpacking.
depmem=$(tar -tzf "$dest" | grep 'meta/deps.txt$' | head -n1 || true)
if [ -n "$depmem" ]; then
  tar -xOzf "$dest" "$depmem" > "$pdir/deps.txt"
else
  [ -f "$pdir/deps.txt" ] || : > "$pdir/deps.txt"
fi

echo "added: $pdir/$name-$ver.tar.gz"
echo "next:  ./tools/rebuild-index.sh && ./tools/sign-index.sh && ./tools/check-repo.sh"