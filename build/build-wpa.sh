#!/bin/sh
# Build wpa_supplicant + wpa_cli (minimal: nl80211 + libnl, internal TLS,
# no openssl) into out/wpa/. Tries static first; falls back to dynamic.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config/versions.env"

out="$ROOT/out/wpa"
if [ -f "$out/wpa_supplicant" ] && [ -z "${FORCE:-}" ]; then
  echo "wpa already built: $out/wpa_supplicant"
  exit 0
fi

mkdir -p "$ROOT/out"

# ---- libnl (nl80211 in modern wpa_supplicant needs it) --------------------
nl="$ROOT/out/libnl"
if [ ! -f "$nl/lib/libnl-3.a" ] && [ ! -f "$nl/lib/libnl-3.so" ]; then
  ( cd "$ROOT/out" \
      && wget -qO libnl.tar.gz "$LIBNL_URL" \
      && tar -xzf libnl.tar.gz \
      && cd "libnl-$LIBNL_VERSION" \
      && ./configure --prefix="$nl" --disable-cli >/dev/null \
      && make -j"$JOBS" >/dev/null \
      && make install >/dev/null )
fi
[ -f "$nl/lib/libnl-3.a" ] || [ -f "$nl/lib/libnl-3.so" ] \
  || { echo "libnl build failed" >&2; exit 1; }

# ---- wpa_supplicant -------------------------------------------------------
src="$ROOT/out/wpa_supplicant-$WPA_VERSION"
if [ ! -d "$src" ]; then
  ( cd "$ROOT/out" \
      && wget -qO wpa.tar.gz "$WPA_URL" \
      && tar -xzf wpa.tar.gz )
fi
[ -d "$src" ] || { echo "failed to fetch/extract wpa_supplicant" >&2; exit 1; }

mkdir -p "$out"
(
  cd "$src/wpa_supplicant"
  cat > .config <<'EOF'
CONFIG_DRIVER_NL80211=y
CONFIG_LIBNL32=y
CONFIG_CTRL_IFACE=y
CONFIG_BACKEND=file
CONFIG_TLS=internal
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_FILE=y
EOF
  export PKG_CONFIG_PATH="$nl/lib/pkgconfig"
  export CFLAGS="-I$nl/include"
  if ! make -j"$JOBS" CC="${CC:-gcc}" LDFLAGS="-L$nl/lib -static" \
       wpa_supplicant wpa_cli >/tmp/wpa-build.log 2>&1; then
    echo "note: static build failed, retrying dynamic (log: /tmp/wpa-build.log)" >&2
    make -j"$JOBS" CC="${CC:-gcc}" LDFLAGS="-L$nl/lib" wpa_supplicant wpa_cli
    touch "$out/NONSTATIC"
  fi
)
cp "$src/wpa_supplicant/wpa_supplicant" "$out/wpa_supplicant"
find "$src/wpa_supplicant" -maxdepth 2 -type f -name wpa_cli -exec cp {} "$out/wpa_cli" \;
[ -f "$out/wpa_cli" ] || { echo "wpa_cli not produced" >&2; exit 1; }

echo "OK: $out/wpa_supplicant + $out/wpa_cli"
[ -f "$out/NONSTATIC" ] && echo "WARNING: built dynamic — build-iso will refuse it (static required in v0)"