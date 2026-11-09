#!/bin/bash
# Load the working copy into the running KWin, without logging out.
# KWin caches QML by path, so every run copies the package to a fresh dir.
#
# Usage: ./dev-reload.sh [hover]
# Logs:  journalctl --user -f | grep snaplayoutshover
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/package"
KS="qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting"

$KS.unloadScript snaplayoutshover >/dev/null 2>&1 || true

BASE="${XDG_RUNTIME_DIR:-/tmp}/snaplayoutshover-dev"
rm -rf "$BASE"
DEV="$BASE/$(date +%s%N)"
mkdir -p "$DEV"
cp -r "$SRC"/. "$DEV"
if [ "$1" = "hover" ]; then
    sed -i 's/readonly property bool devShow: false/readonly property bool devShow: true/' "$DEV/contents/ui/main.qml"
fi
$KS.loadDeclarativeScript "$DEV/contents/ui/main.qml" snaplayoutshover >/dev/null
$KS.start
echo "loaded: $($KS.isScriptLoaded snaplayoutshover)"
