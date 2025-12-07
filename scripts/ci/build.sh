#!/usr/bin/env bash
set -euo pipefail

pull_image() {
  local image="$1" tag="$2" built="$3" pushable="$4" alias="$5"

  if [[ -z "$image" ]]; then
    echo "Image name missing for $alias image" >&2
    return 1
  fi

  local ref
  if [[ "$built" == "true" && "$pushable" == "true" ]]; then
    ref="${image}:${tag}"
  else
    ref="${image}:latest"
  fi

  echo "[build] Pulling $ref for $alias ..."
  if docker pull "$ref"; then
    docker tag "$ref" "$alias"
    return 0
  fi

  echo "[build] Pull failed for $alias; will try to build locally." >&2
  return 1
}

build_image() {
  local alias="$1" dockerfile="$2" image="$3" tag="$4"
  echo "[build] Building $alias from $dockerfile ..."
  docker build -f "$dockerfile" -t "$image:$tag" -t "$image:latest" .
  docker tag "$image:$tag" "$alias"
}

pull_image "${BUILD_IMAGE:-}" "${BUILD_TAG:-}" "${BUILD_BUILT:-false}" "${BUILD_PUSHABLE:-false}" enzos-build || true
pull_image "${RUN_IMAGE:-}" "${RUN_TAG:-}" "${RUN_BUILT:-false}" "${RUN_PUSHABLE:-false}" enzos-run || true

if ! docker image inspect enzos-build >/dev/null 2>&1; then
  build_image enzos-build Dockerfile.build-env "${BUILD_IMAGE:-enzos-build}" "${BUILD_TAG:-latest}"
fi

if ! docker image inspect enzos-run >/dev/null 2>&1; then
  build_image enzos-run Dockerfile.run-env "${RUN_IMAGE:-enzos-run}" "${RUN_TAG:-latest}"
fi

# Ensure the run image still includes Go so smoke and integration tests can use the CLI helpers.
if ! docker run --rm enzos-run go version >/dev/null 2>&1; then
  echo "[build] Go toolchain missing from run image; rebuilding enzos-run ..." >&2
  build_image enzos-run Dockerfile.run-env "${RUN_IMAGE:-enzos-run}" "${RUN_TAG:-latest}"
fi

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
