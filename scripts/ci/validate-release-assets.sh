#!/usr/bin/env bash
set -euo pipefail

required=(enzos.iso changelog.md)
missing=()

for file in "${required[@]}"; do
  if [[ ! -f "release-artifacts/$file" ]]; then
    missing+=("$file")
  fi
done

if ((${#missing[@]})); then
  echo "Missing required release artifacts: ${missing[*]}" >&2
  ls -la release-artifacts
  exit 1
fi

missing_optional=()
for file in qemu-screen-smoke.png qemu-screen-integration.png; do
  if [[ ! -f "release-artifacts/$file" ]]; then
    missing_optional+=("$file")
  fi
done

if ((${#missing_optional[@]})); then
  echo "Optional release artifacts will be skipped: ${missing_optional[*]}"
fi
