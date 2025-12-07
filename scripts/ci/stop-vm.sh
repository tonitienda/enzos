#!/usr/bin/env bash
set -euo pipefail

: "${CONTAINER_NAME:?CONTAINER_NAME is required}"
QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container ${CONTAINER_NAME} is not running; skipping shutdown."
  exit 0
fi

docker exec \
  -e QEMU_MONITOR_ADDR="$QEMU_MONITOR_ADDR" \
  -e QEMU_PIDFILE="$QEMU_PIDFILE" \
  "$CONTAINER_NAME" bash -c '
  set -euo pipefail
  go run ./cmd/main.go monitor exec -addr "${QEMU_MONITOR_ADDR}" -cmd quit || true

  if [[ -f "${QEMU_PIDFILE}" ]]; then
    if kill -0 "$(cat "${QEMU_PIDFILE}")" 2>/dev/null; then
      kill "$(cat "${QEMU_PIDFILE}")" 2>/dev/null || true
    fi
  fi
'

docker stop "$CONTAINER_NAME" >/dev/null || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Stopped container ${CONTAINER_NAME} hosting QEMU."
