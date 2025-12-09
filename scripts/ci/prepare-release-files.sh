#!/usr/bin/env bash
set -euo pipefail

files=(
  release-artifacts/enzos.iso
  release-artifacts/changelog.md
)

for image in \
  release-artifacts/qemu-screen-smoke.png \
  release-artifacts/qemu-screen-integration.png \
  release-artifacts/qemu-screen-integration-terminal.png; do
  if [[ -f "$image" ]]; then
    files+=("$image")
  fi
done

printf '%s\n' "${files[@]}" > release-artifacts/release-files.txt

{
  echo "files<<EOF"
  printf '%s\n' "${files[@]}"
  echo "EOF"
} >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
