#!/bin/sh
# Build a reproducible core bundle from the checked-out release files.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VERSION="$(sed -n 's/^RUIJIE_VERSION="\(.*\)"/\1/p' "$ROOT/lib/common.sh" | head -n1)"
OUT="$ROOT/dist/ruijie-core-${VERSION}.tar.gz"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/ruijie-core/lib" "$STAGE/ruijie-core/init.d"
for file in ruijie.sh ruijie_student.sh ruijie_teacher.sh ruijiectl uninstall.sh install.sh rollback.sh; do cp "$ROOT/$file" "$STAGE/ruijie-core/$file"; done
cp "$ROOT"/lib/*.sh "$STAGE/ruijie-core/lib/"
cp "$ROOT/init.d/ruijie" "$STAGE/ruijie-core/init.d/"
(cd "$STAGE/ruijie-core" && find . -type f ! -name manifest.sha256 -print0 | sort -z | xargs -0 sha256sum > manifest.sha256)
mkdir -p "$ROOT/dist"
tar -C "$STAGE" -czf "$OUT" ruijie-core
printf '%s\n' "$OUT"
