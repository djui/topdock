#!/usr/bin/env bash
# Cuts a release: bumps the version, commits, tags and pushes.
# The GitHub "Release" workflow then builds and publishes the assets.
#
#   scripts/release.sh 0.2.0           # tag + push, CI publishes
#   scripts/release.sh 0.2.0 --local   # additionally build and publish from this machine
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:?usage: scripts/release.sh <version> [--local]}
version=${version#v}
mode=${2:-}
tag="v$version"
plist=Resources/Info.plist

if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like 1.2.3" >&2
  exit 1
fi
if [[ -n $(git status --porcelain) ]]; then
  echo "Working tree is not clean" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists" >&2
  exit 1
fi

build=$(( $(git rev-list --count HEAD) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$plist"

if [[ -n $(git status --porcelain) ]]; then
  git commit -am "Release $tag"
fi
git tag -a "$tag" -m "TopDock $tag"
git push origin HEAD "$tag"

if [[ $mode == "--local" ]]; then
  scripts/package.sh
  gh release create "$tag" \
    "dist/TopDock-$version.dmg" "dist/TopDock-$version.zip" dist/checksums.txt \
    --title "TopDock $tag" --generate-notes
fi

echo "Released $tag"
