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
  if docker pull "$ref"; then
    docker tag "$ref" "$alias"
    return 0
  fi

  if [[ -n "${tag:-}" && "${tag:-}" != "latest" ]]; then
    echo "[build] $ref not found; falling back to ${image}:latest" >&2
    docker pull "${image}:latest"
    docker tag "${image}:latest" "$alias"
    return 0
  fi

  echo "[build] Failed to pull $ref" >&2
  return 1
}

pull_image "${BUILD_IMAGE:-}" "${BUILD_IMAGE_TAG:-${BUILD_TAG:-}}" enzos-build
pull_image "${RUN_IMAGE:-}" "${RUN_IMAGE_TAG:-${RUN_TAG:-}}" enzos-run

docker run --rm enzos-build i686-elf-gcc --version
docker run --rm enzos-run qemu-system-x86_64 --version

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
