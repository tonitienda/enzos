#!/usr/bin/env bash
# Simple script to run shell scenario tests with QEMU
# Usage: ./scripts/run-shell-scenarios-simple.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="${ISO_PATH:-$PROJECT_ROOT/enzos.iso}"
QEMU_MONITOR_ADDR="127.0.0.1:45454"

log() {
  printf '[shell-scenarios] %s\n' "$*" >&2
}

if [[ ! -f "$ISO_PATH" ]]; then
  log "ISO not found at $ISO_PATH"
  log "Build it first with: just build-iso"
  exit 1
fi

# Clean up any existing QEMU processes
pkill -f "qemu-system.*${ISO_PATH##*/}" 2>/dev/null || true
sleep 1

log "Starting QEMU with visible window..."
log "The QEMU window will open - watch the tests run!"
log ""

# Start QEMU in background (visible window)
qemu-system-x86_64 \
  -cdrom "$ISO_PATH" \
  -serial none \
  -no-reboot \
  -no-shutdown \
  -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
  &

QEMU_PID=$!
log "QEMU started with PID $QEMU_PID"

# Wait for QEMU to initialize and monitor to be ready
log "Waiting for QEMU monitor..."
for i in {1..30}; do
  if nc -z 127.0.0.1 45454 2>/dev/null; then
    log "Monitor is ready!"
    break
  fi
  if [[ $i -eq 30 ]]; then
    log "Monitor didn't start in time"
    kill $QEMU_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

log ""
log "Running tests..."
log ""

cd "$PROJECT_ROOT/tests"
export QEMU_MONITOR_ADDR
go test ./cmd -v -run TestShellScenarios

TEST_EXIT=$?

log ""
log "Tests completed. Stopping QEMU..."
kill $QEMU_PID 2>/dev/null || true

exit $TEST_EXIT
