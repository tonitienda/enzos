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

select_tag() {
  local built_flag="$1" requested_tag="$2"
  if [[ "${built_flag}" == "true" && -n "${requested_tag}" ]]; then
    echo "$requested_tag"
  else
    echo "latest"
  fi
}

BUILD_PULL_TAG=$(select_tag "${BUILD_IMAGE_BUILT:-false}" "${BUILD_IMAGE_TAG:-${BUILD_TAG:-}}")
RUN_PULL_TAG=$(select_tag "${RUN_IMAGE_BUILT:-false}" "${RUN_IMAGE_TAG:-${RUN_TAG:-}}")

pull_image "${BUILD_IMAGE:-}" "$BUILD_PULL_TAG" enzos-build
pull_image "${RUN_IMAGE:-}" "$RUN_PULL_TAG" enzos-run

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
