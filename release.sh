#!/usr/bin/env bash
#
#  release.sh – build and tag Clipious for a GitHub release (FMGordillo/clipious)
#
#  Prerequisites
#  • Flutter
#  • devenv shell
#  • Android keystore – a file *android/key.properties* (see below)
#
#  Usage
#  $ ./release.sh              # bump type detected from commits since last tag
#  $ ./release.sh minor        # or force major | minor | patch
#
#  Version bump detection (commits since the last change of the version line in pubspec.yaml):
#    major  – a "!:" commit (e.g. feat!: ...) or a "BREAKING CHANGE:" line
#    minor  – at least one feat: commit
#    patch  – anything else
#  The build number (+N, the Android versionCode) is always incremented.
#
#  The script
#    1. runs the code‑generator
#    2. builds signed per-ABI release APKs (covers mobile and Android TV)
#    3. collects all APK files and generates SHA1 checksums
#    0. decides the bump, asks for confirmation and bumps pubspec.yaml
#    4. (removed – version is handled in step 0)
#    5. commits the bump, creates and pushes a git tag with the same version
#    6. creates a GitHub release for the tag (notes = commit subjects), uploads all APKs and .sha1 files, then publishes it
#
#  Example:   ./release.sh

set -euo pipefail

# ---------- 0. Determine and apply the version bump -------------------------
REQUESTED=${1:-}
case "$REQUESTED" in
    ""|major|minor|patch) ;;
    *) echo "Usage: $0 [major|minor|patch]" >&2; exit 1 ;;
esac

# Fail before any side effect if gh is missing or not logged in
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "gh missing or not logged in (run: gh auth login)" >&2; exit 1; }

if ! git diff --quiet -- pubspec.yaml || ! git diff --cached --quiet; then
    echo "pubspec.yaml or the git index has uncommitted changes; commit or stash them first." >&2
    exit 1
fi

# Current version, e.g. 1.23.01+3 -> MAJOR=1 MINOR=23 PATCH=1 BUILD=3
CURRENT=$(grep '^version:' pubspec.yaml)
CURRENT=${CURRENT#version: }
CUR_NAME=${CURRENT%%+*}
CUR_BUILD=$((10#${CURRENT##*+}))
IFS=. read -r CUR_MAJOR CUR_MINOR CUR_PATCH <<<"$CUR_NAME"
CUR_MAJOR=$((10#$CUR_MAJOR))
CUR_MINOR=$((10#$CUR_MINOR))
CUR_PATCH=$((10#$CUR_PATCH))

# Commits since the last release decide the bump type. The last release is the
# last commit that changed the version line (tags may not be on this branch).
LAST_REL=$(git log -1 --format=%H -G'^version:' -- pubspec.yaml)
RANGE="${LAST_REL:+$LAST_REL..}HEAD"
COMMIT_COUNT=$(git rev-list --no-merges --count "$RANGE")
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "No commits since the last version change; nothing to release." >&2
    exit 1
fi

SUBJECTS=$(git log --no-merges --format='%s' "$RANGE")
BODIES=$(git log --no-merges --format='%b' "$RANGE")
DETECTED=patch
if grep -qE '^feat(\([^)]*\))?:' <<<"$SUBJECTS"; then DETECTED=minor; fi
if grep -qE '^[A-Za-z]+(\([^)]*\))?!:' <<<"$SUBJECTS" || grep -qE '^BREAKING[ -]CHANGE:' <<<"$BODIES"; then
    DETECTED=major
fi
BUMP=${REQUESTED:-$DETECTED}

case "$BUMP" in
    major) CUR_MAJOR=$((CUR_MAJOR + 1)); CUR_MINOR=0; CUR_PATCH=0 ;;
    minor) CUR_MINOR=$((CUR_MINOR + 1)); CUR_PATCH=0 ;;
    patch) CUR_PATCH=$((CUR_PATCH + 1)) ;;
esac
NEW_VERSION="$CUR_MAJOR.$CUR_MINOR.$CUR_PATCH+$((CUR_BUILD + 1))"
TAG="v${NEW_VERSION}"

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag $TAG already exists." >&2
    exit 1
fi

LAST_DESC=$(git log -1 --format='%h %s' "$LAST_REL")
echo "Last release : $LAST_DESC ($COMMIT_COUNT commits since)"
echo "Bump         : $BUMP (detected: $DETECTED)"
echo "New version  : $CURRENT -> $NEW_VERSION"
read -r -p "Proceed? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# If anything fails before the release commit, restore pubspec.yaml
BUMPED=0
on_exit() {
    local rc=$?
    if [ "$rc" -ne 0 ] && [ "$BUMPED" -eq 1 ]; then
        echo "Release failed; restoring pubspec.yaml" >&2
        git checkout -- pubspec.yaml
    fi
}
trap on_exit EXIT

sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
BUMPED=1

# ---------- 1. Build code generator ------------------------------------
echo "Running build_runner to generate code..."
flutter clean && flutter pub get && dart run build_runner build

# ---------- 2. Build release APKs --------------------------------------
# Build signed Android (mobile) release
echo "Building signed Android (mobile) release..."
ANDROID_KEY_FILE=/home/fmgordillo/code/clipious/android/key.properties \
  flutter build apk --release --split-per-abi

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

# ---------- 5. Commit, tag and push ------------------------------------------
git add pubspec.yaml
git commit -m "chore: release $TAG"
BUMPED=0
git tag -a "$TAG" -m "Release ${NEW_VERSION}"
git push origin HEAD "$TAG"

# ---------- 6. GitHub release: create as draft, upload, then publish ---------
# Draft first so a failed upload never leaves a public release with partial assets
gh release create "$TAG" --draft --title "Clipious $NEW_VERSION" \
  --notes "$(sed 's/^/- /' <<<"$SUBJECTS")" \
  "$BUILD_DIR"/*.apk "$BUILD_DIR"/*.sha1
gh release edit "$TAG" --draft=false
echo "Published GitHub release $TAG."
