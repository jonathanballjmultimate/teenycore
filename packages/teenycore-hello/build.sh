#!/bin/sh
# Build and register the teenycore-hello smoke-test package:
#   pack payload -> repo/packages/ -> rebuild index -> sign -> verify
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/tools/repo.env"

name=teenycore-hello
ver=1.0.0

"$ROOT/tools/add-package.sh" "$name" "$ver" "$(dirname "$0")/src"
"$ROOT/tools/rebuild-index.sh"
"$ROOT/tools/sign-index.sh"
"$ROOT/tools/check-repo.sh"

echo
echo "done: $name $ver registered — the repo tree is ready at:"
echo "  $REPO_DIR"