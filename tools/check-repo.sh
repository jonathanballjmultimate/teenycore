#!/bin/sh
# Validate repo/ against index.txt: file existence, size, sha256, deps,
# and (when possible) the index signature itself.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/repo.env"

INDEX="$REPO_DIR/index.txt"
[ -f "$INDEX" ] || { echo "no index.txt" >&2; exit 1; }
[ -f "$REPO_DIR/index.txt.sig" ] && echo "index.txt.sig: present" \
  || { echo "WARN: index.txt.sig missing"; }

names=$(cut -f1 "$INDEX" | sort -u)
bad=0

while IFS=$(printf '\t') read -r name ver size sha path deps; do
  [ -n "$name" ] || continue
  f="$REPO_DIR/$path"
  if [ ! -f "$f" ]; then
    echo "MISSING: $path"; bad=$((bad+1)); continue
  fi
  if [ "$(wc -c < "$f")" != "$size" ]; then
    echo "SIZE MISMATCH: $path"; bad=$((bad+1))
  fi
  if [ "$(sha256sum "$f" | awk '{print $1}')" != "$sha" ]; then
    echo "SHA MISMATCH: $path"; bad=$((bad+1))
  fi
  if [ "$deps" != "-" ]; then
    oldIFS=$IFS; IFS=,
    for d in $deps; do
      IFS=$oldIFS
      if ! printf '%s\n' "$names" | grep -qx "$d"; then
        echo "UNKNOWN DEP: $name -> $d"; bad=$((bad+1))
      fi
    done
    IFS=$oldIFS
  fi
done < "$INDEX"

if [ -x "$SIGNIFY" ] && [ -f "$KEYS_DIR/$KEY_NAME.pub" ]; then
  if "$SIGNIFY" -V -p "$KEYS_DIR/$KEY_NAME.pub" \
      -m "$INDEX" -x "$REPO_DIR/index.txt.sig" >/dev/null 2>&1; then
    echo "signature: OK"
  else
    echo "signature: FAILED"; bad=$((bad+1))
  fi
else
  echo "signature: skipped (signify or pubkey unavailable)"
fi

[ "$bad" -eq 0 ] && echo "repo looks good" \
  || { echo "$bad problem(s) found" >&2; exit 1; }