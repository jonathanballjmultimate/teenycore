#!/bin/sh
# Generate the signify keypair for the Teeny Core repo (run once).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/repo.env"

if [ ! -x "$SIGNIFY" ]; then
  echo "signify not built yet — building it first..."
  "$ROOT/build/build-signify.sh"
fi

mkdir -p "$KEYS_DIR"
if [ -f "$KEYS_DIR/$KEY_NAME.sec" ] || [ -f "$KEYS_DIR/$KEY_NAME.pub" ]; then
  echo "keys already exist at $KEYS_DIR/$KEY_NAME.{sec,pub}" >&2
  echo "remove them first if you really want to regenerate" >&2
  exit 1
fi

"$SIGNIFY" -G -n \
  -p "$KEYS_DIR/$KEY_NAME.pub" \
  -s "$KEYS_DIR/$KEY_NAME.sec"

# Bake the public key into the distro base and serve it from the repo root.
mkdir -p "$ROOT/base/etc/teenycore" "$REPO_DIR"
cp "$KEYS_DIR/$KEY_NAME.pub" "$ROOT/base/etc/teenycore/repo.pub"
cp "$KEYS_DIR/$KEY_NAME.pub" "$REPO_DIR/pubkey"

echo
echo "OK: keypair -> $KEYS_DIR/$KEY_NAME.{sec,pub}"
echo "    the .sec file is SECRET — never commit it (keys/ is gitignored)"
echo "    public key baked into base/etc/teenycore/repo.pub and served at repo/pubkey"
echo
echo "Next: ./packages/teenycore-hello/build.sh   (build+register a test package)"