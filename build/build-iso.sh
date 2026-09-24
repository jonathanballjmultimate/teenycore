#!/bin/sh
# Assemble out/teenycore-<ver>.iso:
#   busybox + signify + wpa + base overlay  ->  initramfs (cpio.gz)
#   initramfs + bzImage                     ->  isolinux bootable ISO
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config/versions.env"
. "$ROOT/tools/repo.env"

MISS=""
for f in out/bzImage out/busybox/busybox out/signify/signify \
         out/wpa/wpa_supplicant out/wpa/wpa_cli; do
  [ -f "$ROOT/$f" ] || MISS="$MISS $f"
done
[ -z "$MISS" ] || { echo "missing build artifacts:$MISS — run ./build/build-all.sh first" >&2; exit 1; }

grep -qi placeholder "$ROOT/base/etc/teenycore/repo.pub" \
  && { echo "run ./tools/keygen.sh first (repo.pub is still a placeholder)" >&2; exit 1; }

if [ -f "$ROOT/out/wpa/NONSTATIC" ]; then
  echo "ERROR: wpa_supplicant is dynamically linked. v0.1 requires static" >&2
  echo "  (no glibc smuggling into the initramfs yet — musl on the roadmap)." >&2
  exit 1
fi

# ---------------------------------------------------------------- rootfs --
R="$ROOT/out/rootfs"
rm -rf "$R"; mkdir -p "$R"

# busybox (installs /bin/sh and all applet links)
( cd "$ROOT/out/busybox-$BUSYBOX_VERSION" && make install CONFIG_PREFIX="$R" >/dev/null )

mkdir -p "$R/usr/bin" "$R/usr/sbin"
cp "$ROOT/out/signify/signify" "$R/usr/bin/signify"
cp "$ROOT/out/wpa/wpa_supplicant" "$ROOT/out/wpa/wpa_cli" "$R/usr/sbin/"

for bin in "$R/usr/sbin/wpa_supplicant" "$R/usr/sbin/wpa_cli"; do
  if ! ldd "$bin" 2>/dev/null | grep -q 'statically linked\|not a dynamic'; then
    echo "ERROR: $bin is dynamic; v0.1 needs everything static" >&2; exit 1
  fi
done

# base overlay (wifi, pkg, init, config)
cp -a "$ROOT/base/." "$R/"

# bake the real repo URL + version
printf 'REPO_URL=%s\nREPO_KEY=/etc/teenycore/repo.pub\n' "$REPO_URL" \
  > "$R/etc/teenycore/repo.conf"
printf '%s\n' "$TC_VERSION" > "$R/etc/teenycore/version"

mkdir -p "$R/proc" "$R/sys" "$R/dev" "$R/tmp" "$R/mnt" "$R/root" \
         "$R/var/run" "$R/var/lock" "$R/var/log" "$R/var/tmp"
chmod 755 "$R"

# ------------------------------------------------------------- initramfs --
( cd "$R" && find . | cpio -o -H newc 2>/dev/null | gzip -9 > "$ROOT/out/initrd.gz" )
echo "initramfs: $ROOT/out/initrd.gz"

# --------------------------------------------------------------- boot ---
I="$ROOT/out/isolinux"; mkdir -p "$I"
SLDIR=""
for d in /usr/lib/syslinux/modules/bios /usr/lib/syslinux /usr/share/syslinux; do
  [ -f "$d/isolinux.bin" ] && SLDIR=$d && break
done
[ -n "$SLDIR" ] || { echo "isolinux.bin not found (install syslinux)" >&2; exit 1; }
cp "$SLDIR/isolinux.bin" "$I/" 2>/dev/null || true
cp "$SLDIR/ldlinux.c32" "$I/" 2>/dev/null || true
cat > "$I/isolinux.cfg" <<'EOF'
DEFAULT teenycore
PROMPT 0
TIMEOUT 50
LABEL teenycore
  LINUX /bzImage
  INITRD /initrd.gz
  APPEND console=tty1
EOF

# ----------------------------------------------------------------- iso --
st="$ROOT/out/iso"
rm -rf "$st"; mkdir -p "$st"
cp "$ROOT/out/bzImage" "$ROOT/out/initrd.gz" "$st/"
cp -a "$I" "$st/"

iso="$ROOT/out/teenycore-$TC_VERSION.iso"
rm -f "$iso"
genisoimage -quiet -input-charset utf-8 -R -J -l \
  -o "$iso" \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -V "TEENYCORE" "$st"
isohybrid "$iso"

echo "OK: $iso ($(wc -c < "$iso") bytes)"