#!/usr/bin/env bash
# Create and push a release tag.
# Usage: scripts/release.sh [version]
#   If version is omitted, reads from pubspec.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(scripts/pubspec-version.sh)}"
VERSION="${VERSION#v}"  # tolerate a pasted leading "v"
TAG="v${VERSION}"

echo "Releasing $TAG (version $VERSION)"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists."
  exit 1
fi

git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"
echo "Pushed tag $TAG — CI will build and publish the release."
