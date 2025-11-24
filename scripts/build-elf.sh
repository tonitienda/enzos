#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"

require_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if ((${#missing[@]} > 0)); then
    echo "[build-elf] Missing tools: ${missing[*]}" >&2
    echo "[build-elf] Ensure the Docker image is built (see Dockerfile) or install the dependencies manually." >&2
    exit 1
  fi
}

build_objects() {
  echo "[build-elf] Assembling kernel entrypoint..."
  i686-elf-as "$REPO_ROOT/src/kernel.s" -o "$BUILD_DIR/kernel_entry.o"

  echo "[build-elf] Compiling kernel..."
  i686-elf-gcc \
    -std=gnu99 \
    -ffreestanding \
    -O2 \
    -Wall -Wextra \
    -c "$REPO_ROOT/src/kernel.c" \
    -o "$BUILD_DIR/kernel.o"
}

link_kernel() {
  echo "[build-elf] Linking kernel ELF..."
  i686-elf-gcc \
    -T "$REPO_ROOT/linker.ld" \
    -o "$BUILD_DIR/enzos.elf" \
    -ffreestanding \
    -O2 \
    -nostdlib \
    "$BUILD_DIR/kernel_entry.o" "$BUILD_DIR/kernel.o" \
    -lgcc
}

main() {
  require_tools i686-elf-as i686-elf-gcc
  mkdir -p "$BUILD_DIR"

  build_objects
  link_kernel

  echo "[build-elf] Done! Output: $BUILD_DIR/enzos.elf"
}

main "$@"
