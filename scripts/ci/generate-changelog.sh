#!/usr/bin/env bash
set -euo pipefail

CURRENT_TAG="${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"

git fetch --tags --force
PREVIOUS_TAG=$(git describe --tags --abbrev=0 "${CURRENT_TAG}^" 2>/dev/null || true)

if [[ -z "$PREVIOUS_TAG" ]]; then
  RANGE="$(git rev-list --max-parents=0 HEAD | tail -n 1)..HEAD"
else
  RANGE="${PREVIOUS_TAG}..${CURRENT_TAG}"
fi

{
  echo "# Changelog for ${CURRENT_TAG}"
  echo ""
  echo "## Commits"
  git log --no-merges --pretty=format:"- %s (%h)" "$RANGE"
} > changelog.md
