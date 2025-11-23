FROM ubuntu:24.04

# Avoid interactive prompts during install (e.g. GRUB, tzdata)
ENV DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------------------------
# 1) Base tools and dependencies
# --------------------------------------------------------------------
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential \
  bison \
  flex \
  libgmp3-dev \
  libmpc-dev \
  libmpfr-dev \
  texinfo \
  libisl-dev \
  wget \
  xz-utils \
  ca-certificates \
  git \
  make \
  nasm \
  grub2-common \
  grub-common \
  xorriso \
  mtools \
  qemu-system-x86 && \
  rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------
# 2) Cross-compiler configuration
# --------------------------------------------------------------------
ENV PREFIX=/opt/cross
ENV TARGET=i686-elf
ENV PATH="$PREFIX/bin:$PATH"
ARG MAKE_JOBS=1

# --------------------------------------------------------------------
# 3) Download binutils + gcc sources
# --------------------------------------------------------------------
# You can change versions later if you want, these are known-good ones.
RUN mkdir -p /usr/src/cross && cd /usr/src/cross && \
  wget https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz && \
  tar xf binutils-2.42.tar.xz && \
  wget https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz && \
  tar xf gcc-13.2.0.tar.xz && \
  cd gcc-13.2.0 && \
  ./contrib/download_prerequisites

# --------------------------------------------------------------------
# 4) Build and install binutils (i686-elf-ld, i686-elf-as, etc.)
# --------------------------------------------------------------------
RUN cd /usr/src/cross && \
  mkdir -p build-binutils && \
  cd build-binutils && \
  ../binutils-2.42/configure \
  --target=$TARGET \
  --prefix=$PREFIX \
  --with-sysroot \
  --disable-nls \
  --disable-werror && \
  make -j"$MAKE_JOBS" && \
  make install

# --------------------------------------------------------------------
# 5) Build and install gcc (i686-elf-gcc)
#    We build only C and without headers for now (freestanding kernel).
# --------------------------------------------------------------------
RUN cd /usr/src/cross && \
  mkdir -p build-gcc && \
  cd build-gcc && \
  ../gcc-13.2.0/configure \
  --target=$TARGET \
  --prefix=$PREFIX \
  --disable-nls \
  --disable-multilib \
  --enable-languages=c \
  --without-headers && \
  make all-gcc -j"$MAKE_JOBS" && \
  make all-target-libgcc -j"$MAKE_JOBS" && \
  make install-gcc && \
  make install-target-libgcc

# --------------------------------------------------------------------
# 6) Workspace for EnzOS sources
# --------------------------------------------------------------------
WORKDIR /src

# By default drop into a shell. In CI you’ll override CMD with your build.
CMD ["/bin/bash"]
