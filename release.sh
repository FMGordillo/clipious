#!/usr/bin/env bash
#
#  release.sh – build, tag and publish Clipious to GitHub Releases
#
#  Prerequisites
#  • Flutter (provided via submodule or system)
#  • make  (homedir /home/fmgordillo/clipious)
#  • github CLI (gh) – selfsigned installs:  sudo apt install gh
#  • Android keystore – a file *android/key.properties* (see below)
#
#  Usage
#  $ ./release.sh
#
#  The script
#    1. runs the code‑generator
#    2. builds signed release APKs for mobile and TV
#    3. extracts the project version from pubspec.yaml
#    4. creates and pushes a git tag with the same version
#    5. creates a draft GitHub release and uploads the two APKs
#    6. (optional) automatically closes the release when uploading is finished
#
#  Example:   ./release.sh

set -euo pipefail

# ---------- 1. Build code generator ------------------------------------
echo "Running build_runner to generate code..."
make build-runner

# ---------- 2. Build release APKs --------------------------------------
echo "Building signed Android (mobile) release..."
make android-prod   # creates build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

echo "Building signed Android (TV) release..."
make tv-prod        # creates build/app/outputs/flutter-apk/app-release.apk

# ---------- 3 uploaded artifacts --------------------------------------
APK_MOBILE="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
APK_TV="build/app/outputs/flutter-apk/appish-release.apk"
# If tv-prod outputs a different filename, adjust accordingly.

# ---------- 4. Determine current version from pubspec.yaml ---------------
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'"' -f2)
TAG="v${VERSION}"
echo "Project version is $VERSION, tag will be $TAG"

# ---------- 5. Tag and push ------------------------------------------
git tag -a "$TAG" -m "Release ${VERSION}"
git push origin "$TAG"

# ---------- 6. Create/draft GitHub release --------------------------------
echo "Creating GitHub release $TAG..."
gh release create "$TAG" \
    --title "Clipious ${VERSION}" \
    --notes "Automated release of Clipious ${VERSION}" \
    --draft \
    "$APK_MOBILE" \
    "$APK_TV"

echo "Release $TAG created in draft mode. Uploading binaries..."
gh release upload "$TAG" "$APK_MOBILE" "$APK_TV"

echo "All done. Remember to publish the release from the GitHub UI."
