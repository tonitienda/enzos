#!/usr/bin/env bash
set -euo pipefail

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-2}"

export QEMU_MONITOR_ADDR
export QEMU_PIDFILE
export VNC_PORT
export VNC_CONNECT_ADDR
export VNC_WAIT_SECONDS

if [[ -n "$QEMU_PIDFILE" && ! -f "$QEMU_PIDFILE" ]]; then
  echo "QEMU pidfile missing at $QEMU_PIDFILE; cannot run integration tests." >&2
  exit 1
fi

if ! kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
  echo "QEMU process not running after boot (pidfile: $QEMU_PIDFILE)." >&2
  exit 1
fi

set +e
go test ./cmd -count=1 -run TestShellScenarios -v -test.timeout=5m
status=$?
set -e

exit "$status"
