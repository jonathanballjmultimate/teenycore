# Teeny Core Linux — roadmap

## v0.1 (this scaffold)

- [x] Signed package repo (signify Ed25519), published via GitHub Pages
- [x] `pkg` — update / search / info / describe / install / remove / list
      with dependency resolution, SHA-256 verification, staged-install mode
- [x] `wifi` — wpa_supplicant/wpa_cli wrapper (scan / connect / status)
- [x] Seed package + host-side repo tooling (keygen, add, rebuild, sign,
      check)
- [ ] ISO build proven end-to-end on a real box (kernel + busybox +
      wpa_supplicant + initramfs + isolinux): `./build/build-all.sh`
- [ ] Boot tested in QEMU and on real hardware

## Next

- [ ] **GUI, the actual point of the distro:** `xorg-server` as a package,
      then a window manager (`dwm` — ~50 KB, only dep is Xlib) and a tiny
      browser. Nothing GUI-flavored lives in the ISO.
- [ ] **Wireless firmware packages** — split `linux-firmware` by directory
      (`firmware-iwlwifi`, `firmware-ath10k`, …). `wifi` suggests the right
      package when it can't bring a NIC up.
- [ ] squashfs packages (`.tcz` style) — read-only, compressed, deduped;
      keeps the installed tree safe from accidental writes.
- [ ] Per-package signatures (defense in depth beyond the index signature).
- [ ] musl static toolchain — fully self-contained initramfs, no host glibc
      carried into the ISO, smaller base.
- [ ] Multiple repo URLs / rsync mirrors / offline repo on USB.
- [ ] Reproducible builds (bit-for-bit given pinned toolchains).
- [ ] `teenycore-build` container image so anyone can build the ISO without
      installing anything.

## Non-goals (for now)

- No systemd, no libc bloat, no installer (the ISO *is* the system).
- No GUI in the base image — GUI ships as packages, on demand.
- No package signing chains of trust to big-CA certificates; trust = the
  signify key in the ISO, end of story.