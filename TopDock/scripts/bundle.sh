#!/usr/bin/env bash
# Builds a universal release binary and wraps it into dist/TopDock.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=${ARCHS:-"arm64 x86_64"}
arch_args=()
for arch in $ARCHS; do arch_args+=(--arch "$arch"); done

swift build -c release "${arch_args[@]}"
bin_dir=$(swift build -c release "${arch_args[@]}" --show-bin-path)

app=dist/TopDock.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/TopDock" "$app/Contents/MacOS/TopDock"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign - --timestamp=none "$app"
codesign --verify --verbose=1 "$app"

echo "Built $app ($(lipo -archs "$app/Contents/MacOS/TopDock"))"
