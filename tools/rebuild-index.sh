#!/bin/sh
# Rebuild repo/index.txt from what actually exists in repo/packages/.
# The newest <name>-*.tar.gz for each package wins the index slot.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/repo.env"

[ -d "$REPO_DIR/packages" ] || { echo "no packages yet — nothing to index" >&2; exit 1; }

INDEX="$REPO_DIR/index.txt"
: > "$INDEX"
n=0

for pdir in "$REPO_DIR"/packages/*/; do
  [ -d "$pdir" ] || continue
  name=$(basename "$pdir")
  tb=$(ls "$pdir"/*.tar.gz 2>/dev/null | sort | tail -n1 || true)
  [ -n "$tb" ] || continue

  base=$(basename "$tb")
  ver=${base#$name-}
  ver=${ver%.tar.gz}
  size=$(wc -c < "$tb")
  sha=$(sha256sum "$tb" | awk '{print $1}')

  deps="-"
  if [ -s "$pdir/deps.txt" ]; then
    deps=$(tr '\n' ',' < "$pdir/deps.txt" | sed 's/,*$//')
    [ -n "$deps" ] || deps="-"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$ver" "$size" "$sha" "packages/$name/$base" "$deps" >> "$INDEX"
  n=$((n+1))
done

echo "index.txt: $n package(s) indexed"
echo "next: ./tools/sign-index.sh"