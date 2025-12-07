#!/usr/bin/env bash
# Helper script to run integration tests locally with a visible QEMU instance.
# This mimics the CI environment but makes it easier to debug timing and rendering issues.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="${ISO_PATH:-$PROJECT_ROOT/enzos.iso}"
QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/enzos-integration-test.pid}"
VNC_PORT="${VNC_PORT:-1}"
VNC_BIND_ADDR="${VNC_BIND_ADDR:-127.0.0.1}"

log() {
  printf '[run-integration-local] %s\n' "$*" >&2
}

cleanup() {
  if [[ -f "$QEMU_PIDFILE" ]]; then
    if kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
      log "Stopping QEMU..."
      kill "$(cat "$QEMU_PIDFILE")" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$QEMU_PIDFILE"
  fi
}
trap cleanup EXIT

if [[ ! -f "$ISO_PATH" ]]; then
  log "ISO not found at $ISO_PATH"
  log "Build it first with: just build-iso"
  exit 1
fi

log "Starting QEMU with monitor at $QEMU_MONITOR_ADDR and VNC on port $VNC_PORT..."
log "You can connect with: vncviewer ${VNC_BIND_ADDR}:${VNC_PORT}"
log ""

# Start QEMU in the background with monitor enabled
# Note: -serial none is used because -daemonize is incompatible with -serial stdio
qemu-system-x86_64 \
  -cdrom "$ISO_PATH" \
  -serial none \
  -no-reboot \
  -no-shutdown \
  -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
  -vnc "${VNC_BIND_ADDR}:${VNC_PORT}" \
  -daemonize \
  -pidfile "$QEMU_PIDFILE" \
  > /tmp/qemu-integration-local.log 2>&1

# Wait for QEMU to start
log "Waiting for QEMU monitor to be ready..."
for i in {1..20}; do
  if go run "$SCRIPT_DIR/cmd/qemu_monitor_client" -mode wait -addr "$QEMU_MONITOR_ADDR" -timeout 2s 2>/dev/null; then
    log "QEMU monitor ready!"
    break
  fi
  if [[ $i -eq 20 ]]; then
    log "Timed out waiting for QEMU monitor"
    exit 1
  fi
  sleep 1
done

log ""
log "QEMU is running. Connect with VNC viewer to watch the tests:"
log "  vncviewer ${VNC_BIND_ADDR}:${VNC_PORT}"
log ""
log "Running integration tests..."
log ""

# Run the Go integration tests
cd "$PROJECT_ROOT"
export QEMU_MONITOR_ADDR
export QEMU_PIDFILE
go test ./scripts -v -run TestShell

log ""
log "Tests complete. QEMU will be shut down now."
