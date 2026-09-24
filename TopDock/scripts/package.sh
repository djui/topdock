#!/usr/bin/env bash
# Bundles TopDock and packages it as a zip and a DMG with SHA-256 checksums in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
zip="dist/TopDock-$version.zip"
dmg="dist/TopDock-$version.dmg"
rm -f "$zip" "$dmg" dist/checksums.txt

ditto -c -k --sequesterRsrc --keepParent dist/TopDock.app "$zip"

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R dist/TopDock.app "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "TopDock" -srcfolder "$staging" -ov -format UDZO "$dmg" >/dev/null

(cd dist && shasum -a 256 "$(basename "$zip")" "$(basename "$dmg")" > checksums.txt)

echo "Packaged:"
cat dist/checksums.txt
