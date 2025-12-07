#!/usr/bin/env bash
set -euo pipefail

: "${CONTAINER_NAME:?CONTAINER_NAME is required}"

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
VNC_PORT="${VNC_PORT:-1}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"

export QEMU_MONITOR_ADDR
export VNC_PORT
export QEMU_PIDFILE
export QEMU_KEEP_ALIVE=true
export QEMU_VNC_LOG=/tmp/qemu-vnc-server.log

docker run --rm -d \
  --name "$CONTAINER_NAME" \
  -e QEMU_MONITOR_ADDR \
  -e QEMU_VNC_LOG \
  -e QEMU_KEEP_ALIVE \
  -e QEMU_PIDFILE \
  -e VNC_PORT \
  -v "$PWD":/src \
  -w /src \
  enzos-run \
  /src/scripts/ci/container-start.sh

echo "Started container ${CONTAINER_NAME} hosting QEMU with monitor ${QEMU_MONITOR_ADDR} and VNC port ${VNC_PORT}."
