#!/bin/sh
# publish-api.sh <owner> <repo-slug> <directory>
# Upload every file in <directory> to GitHub <owner>/<repo-slug> via the
# Contents API — no git install required.
#
#   GITHUB_TOKEN=<token> ./tools/publish-api.sh jonathanballjmultimate \
#       teenycore-repo ./repo
#
# Safety: by default paths under keys/, out/ and repo/ are SKIPPED (they are
# either secret or belong to the other repo). Override with EXCLUDE="".
# The token must have "Contents: write" on the target repo and is read from
# the environment only — never stored.
set -eu

OWNER=${1:?usage: publish-api.sh <owner> <repo-slug> <directory>}
REPO=${2:?}
DIR=${3:?}
EXCLUDE=${EXCLUDE:-"keys out repo"}
[ -n "${GITHUB_TOKEN:-}" ] || { echo "GITHUB_TOKEN not set" >&2; exit 1; }
[ -d "$DIR" ] || { echo "no such directory: $DIR" >&2; exit 1; }

api="https://api.github.com/repos/$OWNER/$REPO"

excluded() { # <path-without-dot-slash>
  p=$1
  for ex in $EXCLUDE; do
    case "$p" in
      "$ex"|"$ex/"*|"$ex"/*) return 0 ;;
    esac
  done
  return 1
}

upload() { # <relpath> <file>
  b64=$(base64 -w0 "$2")
  body=$(printf '{"message":"publish %s","content":"%s"}' "$1" "$b64")
  try=0
  while [ $try -lt 3 ]; do
    code=$(printf '%s' "$body" | curl -s --max-time 30 -o /dev/null -w '%{http_code}' \
      -X PUT "$api/contents/$1" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      --data-binary @-)
    case "$code" in
      201|200) return 0 ;;
      *) try=$((try+1)); sleep 3 ;;
    esac
  done
  echo "FAILED after retries ($code): $1" >&2
  exit 1
}

total=0 done=0
( cd "$DIR" && find . -type f ) | while IFS= read -r f; do
  p=${f#./}
  if excluded "$p"; then
    echo "skip: $p"
    continue
  fi
  upload "$p" "$DIR/$f"
done

echo "published $(find "$DIR" -type f | wc -l | tr -d ' ') candidate(s) to $OWNER/$REPO"