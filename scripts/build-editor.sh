#!/usr/bin/env bash
# Rebuilds the CodeMirror bundle in Resources/editor from editor/src. Run by hand when the editor changes,
# then commit editor/package-lock.json and the files in Resources/editor. Needs Node and npm.
# The normal app build (scripts/build.sh) does not need either, it only copies the committed bundle.
set -euo pipefail
cd "$(dirname "$0")/../editor"
npm ci --no-audit --no-fund
npm run build
cd ..
shasum -a 256 Resources/editor/editor.js
wc -c Resources/editor/editor.js Resources/editor/index.html
