#!/usr/bin/env bash
set -euo pipefail

docker run --rm \
  -v "$PWD":/src \
  -w /src \
  enzos-run \
  bash -c 'shopt -s nullglob; for ppm in qemu-screen-*.ppm; do png="${ppm%.ppm}.png"; convert "$ppm" "$png"; done'
