#!/bin/sh
# Build busybox (static) into out/busybox/busybox.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config/versions.env"

out="$ROOT/out/busybox"
if [ -f "$out/busybox" ] && [ -z "${FORCE:-}" ]; then
  echo "busybox already built: $out/busybox"
  exit 0
fi

src="$ROOT/out/busybox-$BUSYBOX_VERSION"
if [ ! -d "$src" ]; then
  mkdir -p "$ROOT/out"
  ( cd "$ROOT/out" \
      && wget -qO "busybox-$BUSYBOX_VERSION.tar.bz2" "$BUSYBOX_URL" \
      && tar -xjf "busybox-$BUSYBOX_VERSION.tar.bz2" )
fi
[ -d "$src" ] || { echo "failed to fetch/extract busybox" >&2; exit 1; }

cd "$src"
make defconfig >/dev/null 2>&1
# static — nothing to smuggle into the initramfs
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
make -j"$JOBS" CC="${CC:-gcc}" >/dev/null

mkdir -p "$out"
cp busybox "$out/busybox"
echo "OK: $out/busybox (static)"