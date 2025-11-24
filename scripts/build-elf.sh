#!/usr/bin/env bash
set -euo pipefail

# Build the kernel sources into an ELF executable using the cross-compiler
# installed in the enzos-dev Docker image.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

mkdir -p "${BUILD_DIR}"

ASM_SOURCE="${PROJECT_ROOT}/src/kernel.s"
C_SOURCE="${PROJECT_ROOT}/src/kernel.c"
ASM_OBJECT="${BUILD_DIR}/kernel.o"
C_OBJECT="${BUILD_DIR}/kernel_c.o"
ELF_OUTPUT="${BUILD_DIR}/enzos.elf"

# Assemble the low-level entry point.
# -m32 is implied by the cross-compiler target but provided for clarity.
# -fno-pie keeps the binary position dependent, matching the linker script.
echo "[build-elf] Assembling ${ASM_SOURCE}"
i686-elf-gcc -m32 -fno-pie -c "${ASM_SOURCE}" -o "${ASM_OBJECT}"

# Compile the C kernel code for a freestanding environment.
# -ffreestanding avoids host libc assumptions; -nostdlib is handled at link time.
echo "[build-elf] Compiling ${C_SOURCE}"
i686-elf-gcc -m32 -std=gnu99 -ffreestanding -O2 -Wall -Wextra -fno-pie -c "${C_SOURCE}" -o "${C_OBJECT}"

# Link the objects into a 32-bit ELF kernel image using the provided script.
echo "[build-elf] Linking objects into ${ELF_OUTPUT}"
i686-elf-gcc -m32 -T "${PROJECT_ROOT}/linker.ld" -o "${ELF_OUTPUT}" \
  -ffreestanding -O2 -nostdlib -lgcc "${ASM_OBJECT}" "${C_OBJECT}"

echo "[build-elf] Kernel ELF ready at ${ELF_OUTPUT}"
