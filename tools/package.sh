#!/bin/bash
# Build dist/snaplayoutshover-<version>.kwinscript from package/.
#
# A .kwinscript is a zip with metadata.json and contents/ at its top level.
# Install it with: kpackagetool6 --type KWin/Script --install <file>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/package"

VERSION="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' "$SRC/metadata.json")"
ID="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Id"])' "$SRC/metadata.json")"
OUT="$ROOT/dist/$ID-$VERSION.kwinscript"

# Development-only switches must never ship enabled.
if grep -q "readonly property bool devShow: true" "$SRC/contents/ui/main.qml"; then
    echo "error: devShow is on in main.qml" >&2
    exit 1
fi

mkdir -p "$ROOT/dist"
rm -f "$OUT"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r "$SRC"/. "$STAGE"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
(cd "$STAGE" && zip -qr -X "$OUT" metadata.json contents LICENSE)
echo "$OUT"
