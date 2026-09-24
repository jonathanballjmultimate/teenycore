#!/bin/sh
# Build the signify verifier (static, bundled libbsd) into out/signify/signify.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config/versions.env"

out="$ROOT/out/signify"
if [ -x "$out/signify" ] && [ -z "${FORCE:-}" ]; then
  echo "signify already built: $out/signify"
  exit 0
fi

src="$ROOT/out/signify-src"
mkdir -p "$ROOT/out"

if [ ! -d "$src" ]; then
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 -b "$SIGNIFY_BRANCH" "$SIGNIFY_REPO" "$src" 2>/dev/null || true
  fi
fi
if [ ! -d "$src" ]; then
  # no git: pull the codeload tarball instead
  branch=$(printf '%s' "$SIGNIFY_BRANCH" | tr '/' '-')
  ( cd "$ROOT/out" \
      && rm -f signify-src.tar.gz \
      && wget -qO signify-src.tar.gz \
           "https://codeload.github.com/aperezdc/signify/tar.gz/refs/heads/$branch" \
      && tar -xzf signify-src.tar.gz \
      && mv "signify-$branch" "$src" )
fi
[ -d "$src" ] || { echo "failed to fetch signify source" >&2; exit 1; }

mkdir -p "$out"
if ! ( cd "$src" && make BUNDLED_LIBBSD=1 static >/dev/null 2>&1 ); then
  echo "note: 'make BUNDLED_LIBBSD=1 static' failed, retrying dynamic" >&2
  ( cd "$src" && make BUNDLED_LIBBSD=1 >/dev/null 2>&1 ) \
    || { echo "signify build failed" >&2; exit 1; }
fi
cp "$src/signify" "$out/signify"

# health check: signify has no -h; prove it can generate a keypair.
# NB: signify requires the keyname.pub/keyname.sec naming scheme.
t=$(mktemp -d)
"$out/signify" -G -n -p "$t/check.pub" -s "$t/check.sec" >/dev/null 2>&1 \
  && [ -s "$t/check.pub" ] && rm -rf "$t" \
  || { echo "signify binary doesn't run — build problem" >&2; exit 1; }
echo "OK: $out/signify"