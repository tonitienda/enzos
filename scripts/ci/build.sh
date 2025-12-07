#!/usr/bin/env bash
set -euo pipefail

pull_image() {
  local image="$1" tag="$2" alias="$3"

  if [[ -z "$image" ]]; then
    echo "Image name missing for $alias image" >&2
    return 1
  fi

  local ref="${image}:${tag:-latest}"
  echo "[build] Pulling $ref for $alias ..."
  docker pull "$ref"
  docker tag "$ref" "$alias"
}

pull_image "${BUILD_IMAGE:-}" "${BUILD_TAG:-}" enzos-build
pull_image "${RUN_IMAGE:-}" "${RUN_TAG:-}" enzos-run

docker run --rm enzos-build i686-elf-gcc --version
docker run --rm enzos-run qemu-system-x86_64 --version

docker run --rm \
  -v "$PWD":/src \
  -w /src \
  enzos-run \
  bash -c "./scripts/run-tests.sh"

docker run --rm \
  -v "$PWD":/src \
  -w /src \
  enzos-build \
  bash -c "./scripts/build-elf.sh"

docker run --rm \
  -v "$PWD":/src \
  -w /src \
  enzos-build \
  bash -c "./scripts/build-iso.sh"
