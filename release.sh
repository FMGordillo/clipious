#!/usr/bin/env bash
#
#  release.sh – build, tag and publish Clipious to GitHub Releases
#
#  Prerequisites
#  • Flutter
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
#    3. collects all APK files and generates SHA1 checksums
#    4. extracts the project version from pubspec.yaml
#    5. creates and pushes a git tag with the same version
#    6. creates a draft GitHub release and uploads all APKs and checksums
#    7. (optional) automatically closes the release when uploading is finished
#
#  Example:   ./release.sh

set -euo pipefail

# ---------- 1. Build code generator ------------------------------------
echo "Running build_runner to generate code..."
make build-runner

# ---------- 2. Build release APKs --------------------------------------
# Build signed Android (mobile) release
echo "Building signed Android (mobile) release..."
make android-prod   # creates build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Build signed Android (TV) release
echo "Building signed Android (TV) release..."
make tv-prod        # creates build/app/outputs/flutter-apk/app-release.apk

# ---------- 3. Collect all APK files and generate SHA1 checksums -----------------------
echo "Collecting APK files and generating SHA1 checksums..."
BUILD_DIR="build/app/outputs/flutter-apk"

# Find all APK files and extract base names (without extension)
APK_FILES=()
SHA1_FILES=()

for apk_file in "$BUILD_DIR"/*.apk; do
    if [ -f "$apk_file" ]; then
        apk_name=$(basename "$apk_file")
        apk_base="${apk_name%.apk}"
        sha1_file="$apk_base.sha1"

        # Generate SHA1 checksum
        sha1sum "$apk_file" | cut -d' ' -f1 > "$BUILD_DIR/$sha1_file"

        echo "  Generated checksum for $apk_name"

        APK_FILES+=("$apk_file")
        SHA1_FILES+=("$BUILD_DIR/$sha1_file")
    fi
done

echo "Found ${#APK_FILES[@]} APK files to upload"

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
    "${APK_FILES[@]}" \
    "${SHA1_FILES[@]}"

echo "Release $TAG created in draft mode. Uploading binaries..."
gh release upload "$TAG" "${APK_FILES[@]}" "${SHA1_FILES[@]}"

echo "All done. Remember to publish the release from the GitHub UI."
