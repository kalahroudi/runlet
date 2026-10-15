#!/usr/bin/env bash
# Builds build/RunLet.app with the Swift compiler alone. No Xcode project and no SwiftPM needed,
# only the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos14"

# Pick an SDK that the installed compiler can read. The newest one is sometimes ahead of the compiler.
pick_sdk() {
  local candidates=("${SDKROOT:-}" "$(xcrun --show-sdk-path 2>/dev/null || true)")
  while IFS= read -r p; do candidates+=("$p"); done < <(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -r)
  for sdk in "${candidates[@]}"; do
    [ -n "$sdk" ] && [ -d "$sdk" ] || continue
    if echo 'import AppKit' | swiftc -sdk "$sdk" -target "$TARGET" -typecheck - >/dev/null 2>&1; then
      echo "$sdk"; return 0
    fi
  done
  return 1
}
SDK="$(pick_sdk)" || { echo "No usable macOS SDK found. Run: xcode-select --install" >&2; exit 1; }
echo "Using SDK: $SDK"

OUT=build; APP="$OUT/RunLet.app"
rm -rf "$APP" "$OUT/obj"; mkdir -p "$OUT/obj" "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -sdk "$SDK" -target "$TARGET" -O -wmo -parse-as-library -module-name RunLetCore \
  -emit-module -emit-module-path "$OUT/obj/RunLetCore.swiftmodule" \
  -c Sources/RunLetCore/*.swift -o "$OUT/obj/RunLetCore.o"

swiftc -sdk "$SDK" -target "$TARGET" -O -parse-as-library -module-name RunLet \
  -I "$OUT/obj" Sources/RunLet/*.swift "$OUT/obj/RunLetCore.o" \
  -o "$APP/Contents/MacOS/RunLet"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
