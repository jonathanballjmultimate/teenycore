# Teeny Core Linux — Architecture

## Vision (one paragraph)

The install medium is not a software store — it is a *bootstrapper*. A few
megabytes of ISO get you a terminal, a way onto the network, and a verifier.
Everything else — GUI, window manager, browser, tools — lives in a signed,
free-to-mirror package repo and comes down on demand. "Download everything"
is the philosophy: we accept the network as required, and make it *safe*.

## Components

### Two GitHub repos

| Repo             | Contents                                            | Served as            |
|------------------|-----------------------------------------------------|----------------------|
| `teenycore`      | this source tree                                    | plain Git repo       |
| `teenycore-repo` | the generated `repo/` tree                          | GitHub Pages (HTTPS) |

GitHub Pages matters because URLs are stable (`/packages/foo/foo-1.0.tar.gz`
never moves once committed), HTTPS is free, and there's a CDN. The format is
agnostic: the same directory tree can later be rsync'd to a VPS as a mirror
with zero protocol changes.

### The signed index

`repo/index.txt` — one line per package, tab-separated:

```
name<TAB>version<TAB>size<TAB>sha256<TAB>path<TAB>deps
```

`deps` is a comma-separated list, or `-` when empty. `path` is relative to the
repo root.

`repo/index.txt.sig` is a **signify** Ed25519 signature over `index.txt`. The
verification public key ships inside the ISO at `/etc/teenycore/repo.pub` and
is also served at `repo/pubkey` so a curious user can cross-check.

**Trust chain:** ISO contains pubkey → verifies index → index pins each
package's SHA-256 → packages verified before extraction. There is no "trust on
first use" anywhere; a fresh install of the ISO can verify a repo it has never
seen.

### Package format (v0.1: tarballs)

A package is a `.tar.gz` rootfs overlay. It is extracted directly over `/`:

```
usr/bin/foo                  # payload lives at real paths
etc/foo.conf
meta/description.txt         # one-line description (shown by `pkg describe`)
meta/deps.txt                # dependency names, one per line (empty = none)
meta/install.sh              # optional post-install hook (runs with cwd=/)
```

The `meta/` tree is consumed by `pkg` and must never be installed. Later
revisions will move to squashfs images (`.tcz` style) for read-only,
compressed, deduplicated packages.

### The `pkg` command (`base/usr/bin/pkg`)

Pure POSIX shell (`#!/bin/sh`, busybox-ash compatible). State lives under:

| Path                          | Purpose                    |
|-------------------------------|----------------------------|
| `/etc/teenycore/repo.conf`    | repo URL (baked at build)  |
| `/etc/teenycore/repo.pub`     | signify public key         |
| `/var/cache/teenycore/`       | downloaded packages        |
| `/var/lib/teenycore/`         | verified index + install DB|
| `/var/lib/teenycore/index.txt`| the last verified index    |

Every path can be overridden with `TEENYCORE_REPO`, `TEENYCORE_ROOT`
(staged installs — great for testing), `TEENYCORE_CACHE`, `TEENYCORE_LIB`.

Operations:

- `pkg update` — fetch index + signature, verify with signify, swap in. If the
  signature is bad, the old index stays and the command fails loudly.
- `pkg install <pkg>` — depth-first dependency resolution (cycles guarded),
  download each to cache, verify SHA-256, extract to `$ROOT`, run
  `meta/install.sh`, record the file list in
  `/var/lib/teenycore/installed/<name>.files`.
- `pkg remove <pkg>` — delete files listed for the package that no *other*
  installed package also lists; prune empty dirs; drop the install record.
- `pkg search`, `pkg info`, `pkg describe`, `pkg list`.

### The `wifi` command (`base/usr/bin/wifi`)

Wraps `wpa_supplicant` + `wpa_cli` — deliberately *not* D-Bus based, so the
wireless stack is one daemon and one client, no message bus in the base.

- `wifi` — ensure the daemon is up, scan, print networks, prompt to connect
- `wifi list` — scan + list
- `wifi connect <ssid> [passphrase]` — open or PSK network; runs `udhcpc`
  afterwards to grab an address
- `wifi disconnect`, `wifi status`

WPA2-PSK uses wpa_supplicant's internal crypto — no OpenSSL needed in base.

### Boot flow

```
BIOS/UEFI → isolinux/GRUB → kernel bzImage + initrd.gz (cpio, whole rootfs)
→ /init (busybox) → mount proc/sys/dev, spawn /bin/sh on tty1
```

The entire root filesystem is an initramfs: no root partition, nothing to
partition, nothing to damage. USB stick boot = copy ISO bytes. The kernel has
the network/wifi drivers compiled *in* (no module loading in v0.1).

## What's in the ISO (target: < 32 MB)

| Component        | Why                                        |
|------------------|--------------------------------------------|
| Linux kernel     | drivers compiled in, minimal config        |
| busybox          | /bin/sh, coreutils, tar, wget, udhcpc      |
| wpa_supplicant   | wifi (wpa_cli drives it)                   |
| signify          | index verification (static, ~40 KB)        |
| overlay          | `pkg`, `wifi`, `/etc`, init scripts        |

Wireless *firmware* is deliberately NOT in the ISO: `linux-firmware` is
~100 MB and most users only need one NIC's blob. Firmware packages
(`pkg install firmware-iwlwifi` etc.) are on the roadmap; until then, plug in
a NIC whose driver needs no external firmware or drop firmware onto removable
media.

## Security model & limits

- **PKI by key rotation:** if the signing key leaks, ship a new ISO with a new
  pubkey. The repo serves its pubkey so checks can be scripted.
- **Repo has no authz:** anyone can mirror; users choose which repo URL to
  trust — trust comes from the signature, not the URL. Publishing to a
  personal GitHub Pages site is your write-gate.
- **Known weak spots (v0.1):** no per-package signatures (index sig suffices),
  no reproducible offline verification of *metadata* beyond the index, no
  rollback protection for the index itself beyond the signature. All are
  acceptable for bootstrap-era and tracked in `docs/roadmap.md`.

## Roadmap

1. v0.1 — this scaffold + working download engine (signed index, install,
   remove, seed package) + ISO build.
2. GUI: Xorg server as a package, then a WM (dwm: tiny, no deps beyond Xlib)
   and a lightweight browser.
3. squashfs packages + per-package signatures.
4. musl static toolchain (rip the host-glbc dependency out of the build).
5. Mirrors: multiple `REPO_URL`s, rsync-hosted repos, offline repo on USB.
6. Reproducible builds (kernel + initramfs bit-for-bit, given toolchain pins).