#!/usr/bin/env bash
# Builds RunLet and installs it to /Applications (or ~/Applications if that is not writable), then opens it.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
DEST=/Applications; [ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
pkill -x RunLet 2>/dev/null || true
rm -rf "$DEST/RunLet.app"; cp -R build/RunLet.app "$DEST/RunLet.app"
SUPPORT="$HOME/Library/Application Support/RunLet"; mkdir -p "$SUPPORT"
printf '{"repo": "%s", "commit": "%s"}\n' "$PWD" "$(git rev-parse HEAD)" > "$SUPPORT/install.json"
open "$DEST/RunLet.app"
echo "Installed to $DEST/RunLet.app. Look for the icon in the menu bar."
