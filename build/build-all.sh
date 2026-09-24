#!/bin/sh
# Build everything: signify, busybox, wpa, kernel, iso.
# Usage: ./build/build-all.sh [components...]   (default: all five)
#        FORCE=1 ./build/build-all.sh           (rebuild everything)
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)

components=${*:-signify busybox wpa kernel iso}
for c in $components; do
  echo
  echo "================ building $c ================"
  "$ROOT/build/build-$c.sh"
done

echo
echo "All done. Artifacts in $ROOT/out/:"
du -sh "$ROOT"/out/teenycore-*.iso 2>/dev/null || true
echo "Boot it with QEMU, or: dd if=out/teenycore-*.iso of=/dev/sdX bs=4M status=progress"