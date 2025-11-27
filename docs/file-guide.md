# File Guide

This guide summarizes the current files in EnzOS and how they help you explore building a tiny operating system.

## Repository Root

- **AGENTS.md** – House rules for documentation and communication so contributions stay consistent and approachable.
- **README.md** – Milestone checklist that outlines the bootstrapping journey from building toolchains to releasing an ISO.
- **LICENSE** – MIT license granting broad reuse while keeping attribution.
- **Dockerfile** – Reproducible environment that builds an i686 cross-compiler, GRUB tooling, and QEMU. Use it to avoid polluting your host and to keep students on the same versions.

  ```bash
  # Build the image with customizable parallelism for GCC/binutils
  just prepare MAKE_JOBS=4
  ```

- **justfile** – Convenience recipes for building the dev container and verifying the cross-compiler version.

- **grub/grub.cfg** – Bootloader configuration consumed by `grub-mkrescue` to generate an ISO that jumps directly into the EnzOS kernel.

  ```bash
  # Build the container
  just prepare

  # Confirm the toolchain is available
  just doctor
  ```

## Kernel Sources (src/)

- **kernel.s** – Multiboot-compliant entrypoint. It installs the multiboot header, sets up a 16 KiB aligned stack, jumps into `kernel_main`, and halts safely if execution ever returns. Reading through the comments gives context on protected-mode expectations before C code runs.
- **kernel.c** – Minimal VGA text driver and the first C-level `kernel_main` implementation. It initializes an 80x25 text buffer and writes `"EnzOS booted successfully."` so you can visually confirm boot progress.

## Scripts (scripts/)

These helpers automate the host-side flow so you can stay focused on kernel behavior instead of tool plumbing.

- **build-elf.sh** – Picks a toolchain automatically: it prefers the i686 cross compiler from the Docker image but falls back to `gcc -m32` and `as --32` when you install `gcc-multilib` locally. When it uses the host toolchain it defines `ALLOW_HOST_TOOLCHAIN` so the kernel sources compile without the tutorial guardrails.
- **build-iso.sh** – Compiles the kernel, links it, stages the GRUB configuration, and invokes `grub-mkrescue` to produce `enzos.iso`. It requires GRUB utilities plus xorriso and mtools; installing the Docker image or the matching host packages keeps the flow reproducible for learners.
- **qemu-smoketest.sh** – Boots the ISO headlessly, dumps the VGA text buffer, and looks for `"EnzOS booted successfully."`. Set `VNC_SCREENSHOT=docs/assets/qemu-vga.png` to start a temporary VNC server on `${VNC_BIND_ADDR}:${VNC_PORT}` (TCP `5900+VNC_PORT`) so CI can connect from the host; the script saves server and client logs plus an optional screenshot to help you debug why VNC connections failed.
- **run-tests.sh** – Placeholder for unit or integration tests you add later (for example, libc-like helpers or kernel subsystems).

  ```bash
  # Common usage while experimenting with the boot flow
  ./scripts/build-iso.sh
  VNC_SCREENSHOT=docs/assets/qemu-vga.png ./scripts/qemu-smoketest.sh enzos.iso
  ./scripts/run-tests.sh
  ```

## Next Steps

Use the milestones in `README.md` as a roadmap: finish the build script, wire in the GRUB config, and iterate with QEMU. Each completed step gives you a clearer understanding of how the kernel, bootloader, and toolchain fit together.
