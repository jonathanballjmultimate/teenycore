# Teeny Core Linux — Authoring packages

A package is a rootfs overlay plus a `meta/` folder (see
`docs/repo-format.md`). This document is the "how do I package X" guide.

## The 30-second version

```sh
mkdir -p mypkg/usr/bin mypkg/meta
cp my-built-binary mypkg/usr/bin/
echo "A thing I built" > mypkg/meta/description.txt
: > mypkg/meta/deps.txt                       # no dependencies
tar -czf repo/packages/mypkg/mypkg-1.0.tar.gz -C mypkg .
./tools/rebuild-index.sh && ./tools/sign-index.sh && ./tools/check-repo.sh
```

## Adding a package with the tooling

```sh
./tools/keygen.sh                              # once, after keygen
./packages/EXAMPLE/build.sh                    # a recipe that does the above
```

Recipes live under `packages/<name>/` and are small `build.sh` scripts that
produce the tarball straight into `repo/packages/<name>/` and then re-index +
re-sign. `packages/teenycore-hello/` is the canonical example — copy it.

## Rules of thumb

- **Compile for the base, not your desktop.** v0.1 uses the build host's
  toolchain (glibc); build static binaries (`gcc -static`) whenever the
  upstream supports it so packages don't drag in a half-dozen glibc deps.
  A musl toolchain is on the roadmap and will make this universal.
- **Dependencies live in `meta/deps.txt`**, one name per line. `pkg install`
  resolves them automatically everywhere the repo is reachable.
- **`meta/description.txt` is required** — it's what `pkg describe` prints.
- **Put config in `/etc` with sane defaults**, never overwrite a user's
  existing config on reinstall (idempotence).
- **Keep payloads at real paths** (`usr/bin/…`, `etc/…`) — the tarball IS the
  filesystem, there is no staging tree.

## Case study: a window manager (the whole point of this distro)

Say we want `dwm` (≈ 50 KB, depends on Xlib):

1. Package `xorg-server` — the X server itself. Compiled with
   `--disable-*` everything not needed; ships `Xorg`, `xorg.conf`, startx
   scripts, and pulls `xorg-libs` via `meta/deps.txt`.
2. Package `xorg-libs` — the X client libraries dwm links against. Because
   dwm is built *statically* against these, the libs only need to exist at
   dwm's *build* time — the runtime needs `dwm` itself. This keeps the
   installed footprint tiny.
3. Package `dwm`:
   ```
   meta/deps.txt: xorg-server
   usr/bin/dwm
   ```
4. `pkg install dwm` → dependencies pulled, X server in place, `dwm` runs
   from any console. See `docs/window-manager.md` once that package ships.

The pattern generalizes: **GUI apps are just packages whose deps are the
X stack** — nothing GUI-related is ever baked into the ISO.

## Packaging firmware (roadmap)

`linux-firmware` is ~100 MB and mostly irrelevant to any one user. Plan:

- split it by directory (`firmware-iwlwifi`, `firmware-ath10k`, …), each a
  package that unpacks into `/lib/firmware/`
- `wifi` suggests `pkg install firmware-<driver>` when it can't bring the
  NIC up
- until then: NICs with on-chip firmware (common on newer chips) or a
  firmware drop on USB stick.

## Testing a package before shipping

Install into a scratch root — no root privileges, no touching your system:

```sh
TEENYCORE_REPO="file://$PWD/repo" TEENYCORE_ROOT=/tmp/pkg-test \
  TEENYCORE_LIB=/tmp/pkg-test-lib TEENYCORE_CACHE=/tmp/pkg-test-cache \
  ./base/usr/bin/pkg install mypkg
/tmp/pkg-test/usr/bin/...     # exercise it
```