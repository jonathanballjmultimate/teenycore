# Teeny Core Linux — Repository format

The repo is a directory tree served over HTTPS (GitHub Pages by default). It
is summarized by one signed text file and otherwise contains only tarballs.
No database, no server-side logic, no signed-by-a-big-corps certificates —
just files.

## Layout

```
/                              (repo root = GitHub Pages site root)
index.txt                      signed catalog (the only file `pkg` must trust)
index.txt.sig                  signify signature over index.txt
pubkey                         signify public key, for cross-checking
packages/
  <name>/
    <name>-<version>.tar.gz    the package
    deps.txt                   dependency names, one per line (optional)
```

The generated `repo/` directory at the top of this project is exactly this
tree; commit it to the `teenycore-repo` repository and enable GitHub Pages.

## index.txt

Tab-separated, LF, one package per line, no header:

```
name<TAB>version<TAB>size<TAB>sha256<TAB>path<TAB>deps
```

Example:

```
teenycore-hello	1.0.0	142	3e5a...	f4f9	packages/teenycore-hello/teenycore-hello-1.0.0.tar.gz	-
dwm	6.5	88413	ab12...	9981	packages/dwm/dwm-6.5.tar.gz	xorg-server,xorg-libs,libxft
```

- `size` — byte size of the tarball (guard against truncation)
- `sha256` — hex digest of the tarball (guard against tampering)
- `path` — URL path relative to the repo root
- `deps` — comma-separated package names, or `-`
- `name` must match `[a-z0-9][a-z0-9+._-]*` (parser-friendly)

Only the **latest** version of each package appears in the index; old tarballs
may remain on disk (they're still fetchable by URL) but aren't offered.

## Package tarball

Any tar.gz that **overlays the root filesystem**, plus a `meta/` tree:

```
usr/bin/foo                     # lands at /usr/bin/foo
etc/foo.conf                    # lands at /etc/foo.conf
meta/description.txt            # REQUIRED, one line
meta/deps.txt                   # optional; empty file = no deps
meta/install.sh                 # optional post-install hook
```

Conventions for `meta/install.sh`:

- It runs after extraction, with the working directory set to `/`
- It must be idempotent (safe to re-run)
- It must not fail on re-install/upgrade
- It may read `$TEENYCORE_ROOT` if it needs the staged-install root
- It should *not* delete files owned by other packages

`pkg` never installs anything under `meta/`.

## Procedures (host side, in `tools/`)

| Step                        | Command                          |
|-----------------------------|----------------------------------|
| create the keypair (once)   | `./tools/keygen.sh`              |
| build+register a package    | `./tools/add-package.sh`         |
| regenerate index.txt        | `./tools/rebuild-index.sh`       |
| sign index.txt              | `./tools/sign-index.sh`          |
| sanity-check the whole tree | `./tools/check-repo.sh`          |

Workflow for shipping a package:

1. Author the payload + `meta/` (see `docs/packaging.md`).
2. `tar -czf repo/packages/<name>/<name>-<ver>.tar.gz -C <payloaddir> .`
3. `./tools/rebuild-index.sh && ./tools/sign-index.sh`
4. `./tools/check-repo.sh`
5. Commit `repo/` to `teenycore-repo`, push → Pages updates in ~1 minute.

## Verification chain

```
ISO  ──contains──►  key: /etc/teenycore/repo.pub
                          │  signify -V   (index.txt.sig, index.txt)
                          ▼
                    index.txt  (name, version, size, sha256, deps)
                          │  sha256sum    (each tarball)
                          ▼
                    package tarball  ──►  extracted to /
```

Failure at any link aborts the operation and prints why. There is no
`--force` that skips verification.