#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"

echo "[qemu-smoketest] TODO: run QEMU with $ISO_PATH"
# Later:
#   timeout 20s qemu-system-x86_64 -cdrom "$ISO_PATH" -serial stdio -nographic | tee qemu.log
#   grep "EnzOS boot OK" qemu.log
exit 1
