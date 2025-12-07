#!/usr/bin/env bash
set -euo pipefail

: "${CONTAINER_NAME:?CONTAINER_NAME is required}"

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"

exec docker exec \
  -w /src \
  -e QEMU_MONITOR_ADDR="$QEMU_MONITOR_ADDR" \
  -e QEMU_PIDFILE="$QEMU_PIDFILE" \
  -e VNC_PORT="$VNC_PORT" \
  -e VNC_CONNECT_ADDR="$VNC_CONNECT_ADDR" \
  "$CONTAINER_NAME" \
  /src/scripts/ci/inside-integration-test.sh
