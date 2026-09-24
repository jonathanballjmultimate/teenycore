# Teeny Core Linux — "Download everything" edition

A tiny Linux distro whose motto is: **the ISO is just a door.** It boots to a
plain CLI in a few megabytes; the network (`wifi`) and the package manager
(`pkg`) do the rest. Want a GUI / window manager? `pkg install` it — the bits
live in a signed package repo, not on the CD.

```
┌──────────────┐   wifi    ┌──────────────┐   pkg update    ┌───────────────────┐
│  Teeny Core  │ ────────► │  the internet │ ──────────────► │  signed repo      │
│  ISO (CLI)   │          │  (GitHub Pages)│                │  index.txt + .sig │
└──────────────┘          └──────────────┘    pkg install   └─────────┬─────────┘
                                                                      │
                                        ┌──────────────┐              ▼
                                        │  WM / GUI /  │ ◄── tarballs (rootfs
                                        │  anything    │      overlays)
                                        └──────────────┘
```

## Why it's trustworthy

Every download is verified twice:

1. `pkg update` fetches `index.txt` and checks its **signify signature**
   against a public key baked into the ISO. A tampered index is rejected.
2. `pkg install` re-checks each package's SHA-256 against what the *signed*
   index says. A tampered package is rejected.

This closes the "MITM the mirror" hole that Tiny Core Linux has had open for
two decades.

## Layout

```
docs/               design docs (read these first)
config/             pinned upstream versions
tools/              repo tooling: keygen, add/rebuild/sign/check
base/               the ISO's root filesystem (wifi, pkg, config)
packages/           recipes for packages we ship in the repo
build/              scripts that assemble the ISO
repo/  (generated)  publish tree for the teenycore-repo GitHub Pages site
keys/  (generated)  signify keypair — SECRET, never commit keys/*.sec
out/   (generated)  build artifacts
```

## Two GitHub repos

| Repo              | Purpose                                                    |
|-------------------|------------------------------------------------------------|
| `teenycore`       | this project: source, build scripts, `wifi` + `pkg`        |
| `teenycore-repo`  | the package repo, published as GitHub Pages                |

Everything under `repo/` is the *content* of `teenycore-repo`. Point GitHub
Pages at that directory's branch and you get
`https://<user>.github.io/teenycore-repo/` for free.

## Quickstart

### 1. Test the download engine on your dev machine (5 min, no root)

```sh
./build/build-signify.sh              # build the signify verifier (tiny, fast)
./tools/keygen.sh                     # create the repo keypair
./packages/teenycore-hello/build.sh   # build + sign a test package

# serve the repo over real HTTP (file:// isn't supported by modern wget)
python3 -m http.server 8123 --directory "$PWD/repo" &

export TEENYCORE_REPO=http://127.0.0.1:8123
export TEENYCORE_ROOT=/tmp/tc-root TEENYCORE_LIB=/tmp/tc-lib TEENYCORE_CACHE=/tmp/tc-cache
export REPO_KEY="$PWD/base/etc/teenycore/repo.pub"   # the key baked into the ISO
export PATH="$PWD/out/signify:$PATH"

./base/usr/bin/pkg update              # fetch + verify the signed index
./base/usr/bin/pkg install teenycore-hello
/tmp/tc-root/usr/bin/teenycore-hello   # "tee-hee! …"
./base/usr/bin/pkg remove teenycore-hello
```

You can also point `TEENYCORE_ROOT` at a scratch dir (as above) to stage
installs without touching your system, and `pkg remove` will prove it
uninstalls cleanly.

**Before publishing anything:** set `GITHUB_USER` in `tools/repo.env` — it
bakes the real repo URL into the ISO. Everything under `repo/` is the content
of your `teenycore-repo` GitHub Pages site.

### 2. Build the actual ISO (needs a Linux box, ~20–40 min)

```sh
./build/build-all.sh          # busybox, wpa_supplicant, kernel, ISO
# out/teenycore-<ver>.iso  — boot it in QEMU or write to USB with dd
```

Requires: `gcc make curl wget sed grep awk tar cpio gzip genisoimage
isohybrid syslinux`. Everything else is downloaded and built in `out/`.

## Commands on the box

| Command            | What it does                                          |
|--------------------|-------------------------------------------------------|
| `wifi`             | scan for networks and connect                          |
| `wifi connect SSID [pass]` | connect to a network                          |
| `pkg update`       | fetch + verify the signed package index               |
| `pkg search TERM`  | find packages                                         |
| `pkg install PKG`  | resolve deps, download, verify, install               |
| `pkg remove PKG`   | uninstall (files not used by other packages)          |
| `pkg list`         | what's installed                                      |

## Roadmap

- [ ] v0.1: boot to CLI, `wifi`, `pkg`, signed repo, seed package
- [ ] Xorg + a window manager (dwm/icewm) as installable packages
- [ ] wireless firmware as installable packages (`linux-firmware` is huge —
      keep it out of the ISO, pull it on demand)
- [ ] squashfs packages (`.tcz` style) instead of tarballs
- [ ] musl toolchain build for a smaller, fully-static base
- [ ] rsync mirrors / multiple repo URLs

## License / credits

GPL-2.0+ (kernel, busybox, wpa_supplicant all GPL). Inspired by — and
respectfully standing on the shoulders of — Tiny Core Linux, whose
"download what you need" model this project re-implements with a modern
signing story and a from-scratch build.