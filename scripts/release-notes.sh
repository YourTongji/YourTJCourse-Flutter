#!/usr/bin/env bash
# Generate release notes since the previous version tag.
# Usage: release-notes.sh <version> <tag>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$1"
TAG="$2"

# Find the previous tag for changelog range.
PREV_TAG="$(git tag -l 'v*' --sort=-v:refname | head -2 | tail -1 || true)"

echo "## YourTJ Course $VERSION"
echo ""

if [ -n "$PREV_TAG" ]; then
  echo "### Changes since $PREV_TAG"
  echo ""
  git log --oneline --no-decorate "${PREV_TAG}..HEAD" 2>/dev/null | sed 's/^/- /' || true
else
  echo "### Commits in this release"
  echo ""
  git log --oneline --no-decorate "$TAG" 2>/dev/null | sed 's/^/- /' || true
fi
