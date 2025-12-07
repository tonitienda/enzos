#!/usr/bin/env bash
set -euo pipefail

docker run --rm \
  -v "$PWD":/src \
  -w /src \
  enzos-run \
  bash -c "if [[ -f qemu-screen-smoke.ppm ]]; then convert qemu-screen-smoke.ppm qemu-screen-smoke.png; fi; if [[ -f qemu-screen-integration.ppm ]]; then convert qemu-screen-integration.ppm qemu-screen-integration.png; fi; if [[ -f qemu-screen-integration-terminal.ppm ]]; then convert qemu-screen-integration-terminal.ppm qemu-screen-integration-terminal.png; fi"
