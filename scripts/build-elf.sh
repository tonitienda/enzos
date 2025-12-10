#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/os"
BUILD_DIR="$REPO_ROOT/build"
EXTRA_CFLAGS=()
COMMON_CFLAGS=()
LIBS=()

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

select_toolchain() {
  # Prefer a cross compiler when available because it avoids accidentally
  # picking up host headers or libraries. When the cross tools are missing we
  # fall back to 32-bit host tools so contributors can still build locally
  # after installing gcc-multilib and binutils.
  if command -v i686-elf-gcc >/dev/null 2>&1 && command -v i686-elf-as >/dev/null 2>&1; then
    export AS=i686-elf-as
    export CC=i686-elf-gcc
    LIBS=(-lgcc)
    return
  fi

  require_tools as gcc
  export AS="as --32"
  export CC="gcc -m32"
  EXTRA_CFLAGS=(-DALLOW_HOST_TOOLCHAIN)
  LIBS=()
}

build_objects() {
  echo "[build-elf] Assembling kernel entrypoint..."
  $AS "$REPO_ROOT/src/kernel.s" -o "$BUILD_DIR/kernel_entry.o"

  echo "[build-elf] Compiling kernel..."
  $CC \
    "${COMMON_CFLAGS[@]}" \
    -c "$REPO_ROOT/src/kernel.c" \
    -o "$BUILD_DIR/kernel.o"

  echo "[build-elf] Compiling shell..."
  $CC \
    "${COMMON_CFLAGS[@]}" \
    -c "$REPO_ROOT/src/shell/shell.c" \
    -o "$BUILD_DIR/shell.o"

  echo "[build-elf] Compiling shell commands..."
  $CC \
    "${COMMON_CFLAGS[@]}" \
    -c "$REPO_ROOT/src/shell/commands.c" \
    -o "$BUILD_DIR/commands.o"

  echo "[build-elf] Compiling terminal driver..."
  $CC \
    "${COMMON_CFLAGS[@]}" \
    -c "$REPO_ROOT/src/drivers/terminal.c" \
    -o "$BUILD_DIR/terminal.o"

  echo "[build-elf] Compiling keyboard driver..."
  $CC \
    "${COMMON_CFLAGS[@]}" \
    -c "$REPO_ROOT/src/drivers/keyboard.c" \
    -o "$BUILD_DIR/keyboard.o"
}

link_kernel() {
  echo "[build-elf] Linking kernel ELF..."
  $CC \
    -T "$REPO_ROOT/linker.ld" \
    -o "$BUILD_DIR/enzos.elf" \
    -ffreestanding \
    -O2 \
    -nostdlib \
    "$BUILD_DIR/kernel_entry.o" "$BUILD_DIR/kernel.o" "$BUILD_DIR/shell.o" "$BUILD_DIR/commands.o" "$BUILD_DIR/terminal.o" "$BUILD_DIR/keyboard.o" \
    "${LIBS[@]}"
}

main() {
  select_toolchain
  COMMON_CFLAGS=(
    -std=gnu99
    -ffreestanding
    -O2
    -Wall -Wextra
    -I "$REPO_ROOT/src"
    "${EXTRA_CFLAGS[@]}"
  )
  mkdir -p "$BUILD_DIR"

  build_objects
  link_kernel

  echo "[build-elf] Done! Output: $BUILD_DIR/enzos.elf"
}

main "$@"
