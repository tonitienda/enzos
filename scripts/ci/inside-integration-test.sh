#!/usr/bin/env bash
set -euo pipefail

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"

export QEMU_MONITOR_ADDR

# Check if QEMU is already running (started by start-vm action)
if [[ -n "$QEMU_PIDFILE" && -f "$QEMU_PIDFILE" ]]; then
  if kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
    echo "Using existing QEMU process from pidfile $QEMU_PIDFILE" >&2
    # Run tests against already-running QEMU
    cd /src/tests
    exec go test ./cmd -count=1 -run TestShellScenarios -v -test.timeout=5m
  fi
fi

# If QEMU is not running, use the simplified script
echo "No running QEMU found, using integration-test script" >&2
export HEADLESS=true
export ISO_PATH=/src/enzos.iso
exec /src/scripts/integration-test.sh --headless
