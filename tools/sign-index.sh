#!/bin/sh
# Sign repo/index.txt with signify (produces index.txt.sig).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/repo.env"

[ -f "$REPO_DIR/index.txt" ] || { echo "no index.txt — run rebuild-index.sh first" >&2; exit 1; }
[ -f "$KEYS_DIR/$KEY_NAME.sec" ] || { echo "no private key — run keygen.sh first" >&2; exit 1; }

"$SIGNIFY" -S \
  -s "$KEYS_DIR/$KEY_NAME.sec" \
  -m "$REPO_DIR/index.txt" \
  -x "$REPO_DIR/index.txt.sig"

[ -f "$REPO_DIR/pubkey" ] || cp "$KEYS_DIR/$KEY_NAME.pub" "$REPO_DIR/pubkey"

echo "signed: index.txt -> index.txt.sig"
echo "next: ./tools/check-repo.sh"