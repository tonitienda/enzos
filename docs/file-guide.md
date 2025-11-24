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

These helpers are scaffolding—you will flesh them out as the OS grows. Each script currently prints a TODO so you know where to plug in future logic.

- **build-iso.sh** – Will compile the assembly and C kernel objects, link them, stage a GRUB configuration, and invoke `grub-mkrescue` to produce `enzos.iso`. Requires the cross-compiler and GRUB utilities available inside the Docker image.
- **qemu-smoketest.sh** – Will boot the generated ISO in headless QEMU, stream serial output, and check for the success message to automate regression testing.
- **run-tests.sh** – Placeholder for unit or integration tests you add later (for example, libc-like helpers or kernel subsystems).

  ```bash
  # Expected usage patterns once implemented
  ./scripts/build-iso.sh
  ./scripts/qemu-smoketest.sh enzos.iso
  ./scripts/run-tests.sh
  ```

## Next Steps

Use the milestones in `README.md` as a roadmap: finish the build script, add a GRUB config, and iterate with QEMU. Each completed step gives you a clearer understanding of how the kernel, bootloader, and toolchain fit together.
