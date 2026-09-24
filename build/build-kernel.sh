#!/bin/sh
# Build the Teeny Core kernel (x86_64 defconfig + tweaks) into out/bzImage.
# Drivers are compiled IN (no module loading in v0.1).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config/versions.env"

out="$ROOT/out/bzImage"
if [ -f "$out" ] && [ -z "${FORCE:-}" ]; then
  echo "kernel already built: $out"
  exit 0
fi

src="$ROOT/out/linux-$KERNEL_VERSION"
if [ ! -d "$src" ]; then
  mkdir -p "$ROOT/out"
  ( cd "$ROOT/out" \
      && wget -qO "linux-$KERNEL_VERSION.tar.xz" "$KERNEL_URL" \
      && tar -xJf "linux-$KERNEL_VERSION.tar.xz" )
fi
[ -d "$src" ] || { echo "failed to fetch/extract kernel" >&2; exit 1; }

cd "$src"
[ -f .config ] || make defconfig >/dev/null 2>&1

./scripts/config \
  -e BLK_DEV_INITRD \
  -e DEVTMPFS -e DEVTMPFS_MOUNT \
  -e SQUASHFS -e SQUASHFS_XZ \
  -e TMPFS \
  -e NET -e WIRELESS -e CFG80211 -e MAC80211 \
  -e IWLWIFI -e IWLMVM -e ATH9K -e ATH9K_HTC -e MT76 -e RTL8XXXU \
  -e USB_SUPPORT -e USB_XHCI_HCD -e USB_EHCI_HCD -e USB_STORAGE \
  -e VIRTIO_PCI -e VIRTIO_NET -e VIRTIO_BLK \
  -e UNIX -e INET -e PACKET -e BINFMT_ELF

# NOTE: no wireless *firmware* blobs are included — most NICs need their
# driver's firmware in /lib/firmware. Get it via firmware packages (roadmap)
# or drop files from linux-firmware onto removable media. Wired NICs today.

make -j"$JOBS" bzImage >/dev/null
cp arch/x86/boot/bzImage "$out"
echo "OK: $out"