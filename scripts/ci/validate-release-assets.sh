#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_ROOT="${1:-release-artifacts}"

if [[ -d "$ARTIFACT_ROOT" ]]; then
  BASE_DIR="$ARTIFACT_ROOT"
elif [[ -d "." ]]; then
  BASE_DIR="."
else
  echo "Artifact root '$ARTIFACT_ROOT' does not exist." >&2
  exit 1
fi

require_file() {
  local path="$1" description="$2"
  if [[ ! -f "$path" ]]; then
    echo "Missing ${description}: $path" >&2
    exit 1
  fi
  if [[ ! -s "$path" ]]; then
    echo "${description} is empty: $path" >&2
    exit 1
  fi
  echo "✓ Found ${description} at $path"
}

ISO_PATH="${BASE_DIR}/enzos.iso"
require_file "$ISO_PATH" "ISO image"

CHANGELOG_CANDIDATES=(
  "${BASE_DIR}/CHANGELOG.md"
  "${BASE_DIR}/changelog.md"
  "${BASE_DIR}/changelog.txt"
)

CHANGELOG_PATH=""
for candidate in "${CHANGELOG_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    CHANGELOG_PATH="$candidate"
    break
  fi
done

if [[ -z "$CHANGELOG_PATH" ]]; then
  echo "Missing changelog file (expected one of: ${CHANGELOG_CANDIDATES[*]})." >&2
  exit 1
fi

require_file "$CHANGELOG_PATH" "changelog"

SCREENSHOT_DIR="${BASE_DIR}/test-screenshots"
if [[ -d "$SCREENSHOT_DIR" ]]; then
  if compgen -G "${SCREENSHOT_DIR}/*" > /dev/null; then
    echo "✓ Found test screenshots in ${SCREENSHOT_DIR}"
  else
    echo "Warning: ${SCREENSHOT_DIR} is present but empty." >&2
  fi
else
  echo "Note: ${SCREENSHOT_DIR} not found; continuing without screenshots."
fi
