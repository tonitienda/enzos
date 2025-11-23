# Minimal-ish Ubuntu image with everything needed to build EnzOS ISO
FROM ubuntu:24.04

# Avoid interactive prompts during install (e.g. GRUB, tzdata)
ENV DEBIAN_FRONTEND=noninteractive

# Basic OS packages + toolchain + GRUB + ISO tools + QEMU
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      nasm \
      grub-pc-bin \
      grub-common \
      xorriso \
      qemu-system-x86 \
      make \
      git \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Optional: set a working directory inside the container
WORKDIR /src

# By default just show help; in CI/locally you'll override the command
CMD ["/bin/bash"]
