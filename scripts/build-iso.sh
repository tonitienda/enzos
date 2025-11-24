#!/usr/bin/env bash
set -euo pipefail

# Build paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
ISO_ROOT="$REPO_ROOT/iso-root"
BOOT_DIR="$ISO_ROOT/boot"
GRUB_DIR="$BOOT_DIR/grub"
ISO_OUTPUT="$REPO_ROOT/enzos.iso"

require_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if ((${#missing[@]} > 0)); then
    echo "[build-iso] Missing tools: ${missing[*]}" >&2
    echo "[build-iso] Ensure the Docker image is built (see Dockerfile) or install the dependencies manually." >&2
    exit 1
  fi
}

verify_kernel_exists() {
  if [ ! -f "$BUILD_DIR/enzos.elf" ]; then
    echo "[build-iso] Missing $BUILD_DIR/enzos.elf. Run scripts/build-elf.sh first." >&2
    exit 1
  fi
}

stage_iso_root() {
  echo "[build-iso] Staging ISO root..."
  rm -rf "$ISO_ROOT"
  mkdir -p "$GRUB_DIR"

  cp "$BUILD_DIR/enzos.elf" "$BOOT_DIR/enzos.elf"
  cp "$REPO_ROOT/grub/grub.cfg" "$GRUB_DIR/grub.cfg"
}

create_iso() {
  echo "[build-iso] Creating ISO image..."
  grub-mkrescue -o "$ISO_OUTPUT" "$ISO_ROOT"
}

main() {
  require_tools grub-mkrescue xorriso mtools
  verify_kernel_exists
  stage_iso_root
  create_iso

  echo "[build-iso] Done! Output: $ISO_OUTPUT"
}

main "$@"
