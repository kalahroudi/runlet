#!/usr/bin/env bash
# Builds RunLet and installs it to /Applications (or ~/Applications if that is not writable), then opens it.
set -euo pipefail
cd "$(dirname "$0")/.."
# The app runs this script without HOME in its environment, so do not rely on it.
HOME="${HOME:-$(eval echo "~$(id -un)")}"
./scripts/build.sh
DEST=/Applications; [ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
SUPPORT="$HOME/Library/Application Support/RunLet"; mkdir -p "$SUPPORT"
printf '{"repo": "%s", "commit": "%s"}\n' "$PWD" "$(git rev-parse HEAD)" > "$SUPPORT/install.json"
pkill -x RunLet 2>/dev/null || true
rm -rf "$DEST/RunLet.app"; cp -R build/RunLet.app "$DEST/RunLet.app"
open "$DEST/RunLet.app"
echo "Installed to $DEST/RunLet.app. Look for the icon in the menu bar."
