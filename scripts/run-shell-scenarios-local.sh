#!/usr/bin/env bash
# Helper script to run shell scenario tests locally
# Usage: ./scripts/run-shell-scenarios-local.sh [--headless]
#
# By default, QEMU runs with a visible window so you can watch the tests.
# Use --headless to run in background mode (requires VNC to view).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="${ISO_PATH:-$PROJECT_ROOT/enzos.iso}"
QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/enzos-shell-scenarios.pid}"
VNC_PORT="${VNC_PORT:-1}"
VNC_BIND_ADDR="${VNC_BIND_ADDR:-127.0.0.1}"
HEADLESS=false
QEMU_PID=""

# Parse arguments
if [[ "${1:-}" == "--headless" ]]; then
  HEADLESS=true
fi

log() {
  printf '[shell-scenarios] %s\n' "$*" >&2
}

go_tool() {
  (cd "$PROJECT_ROOT" && go run ./cmd/main.go "$@")
}

cleanup() {
  if [[ -f "$QEMU_PIDFILE" ]]; then
    SAVED_PID=$(cat "$QEMU_PIDFILE")
    # Only kill if it's our process
    if [[ "$SAVED_PID" == "${QEMU_PID:-}" ]] && kill -0 "$SAVED_PID" 2>/dev/null; then
      log "Stopping QEMU (PID $SAVED_PID)..."
      kill "$SAVED_PID" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$QEMU_PIDFILE"
  fi
}
trap cleanup EXIT

# Check if another instance is already running
if [[ -f "$QEMU_PIDFILE" ]]; then
  OLD_PID=$(cat "$QEMU_PIDFILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    log "Another QEMU instance is already running (PID $OLD_PID)"
    log "Kill it first with: kill $OLD_PID"
    exit 1
  else
    log "Cleaning up stale pidfile..."
    rm -f "$QEMU_PIDFILE"
  fi
fi

if [[ ! -f "$ISO_PATH" ]]; then
  log "ISO not found at $ISO_PATH"
  log "Build it first with: just build-iso"
  exit 1
fi

if [[ "$HEADLESS" == "true" ]]; then
  log "Starting QEMU in headless mode with monitor at $QEMU_MONITOR_ADDR and VNC on port $VNC_PORT..."
  log "Connect with VNC viewer to watch: vncviewer ${VNC_BIND_ADDR}:${VNC_PORT}"
  log ""

  qemu-system-x86_64 \
    -cdrom "$ISO_PATH" \
    -serial none \
    -no-reboot \
    -no-shutdown \
    -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
    -vnc "${VNC_BIND_ADDR}:${VNC_PORT}" \
    -daemonize \
    -pidfile "$QEMU_PIDFILE" \
    > /tmp/qemu-shell-scenarios.log 2>&1
  
  QEMU_PID=$(cat "$QEMU_PIDFILE")
  log "QEMU started with PID $QEMU_PID"
else
  log "Starting QEMU with visible window and monitor at $QEMU_MONITOR_ADDR..."
  log "Watch the tests run in the QEMU window!"
  log ""

  # Start QEMU in background, capturing all output
  qemu-system-x86_64 \
    -cdrom "$ISO_PATH" \
    -serial none \
    -no-reboot \
    -no-shutdown \
    -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
    >> /tmp/qemu-shell-scenarios.log 2>&1 &
  
  QEMU_PID=$!
  echo "$QEMU_PID" > "$QEMU_PIDFILE"
  log "QEMU started with PID $QEMU_PID"
  
  # Give QEMU a moment to initialize
  sleep 2
  
  # Check if QEMU is still running
  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    log "ERROR: QEMU process died immediately after starting!"
    log "Check the log for errors:"
    cat /tmp/qemu-shell-scenarios.log
    exit 1
  fi
fi

log "Waiting for QEMU monitor to be ready..."
for i in {1..20}; do
  if go_tool monitor wait -addr "$QEMU_MONITOR_ADDR" -timeout 2s 2>/dev/null; then
    log "QEMU monitor ready!"
    break
  fi
  if [[ $i -eq 20 ]]; then
    log "Timed out waiting for QEMU monitor"
    log ""
    log "QEMU log contents:"
    cat /tmp/qemu-shell-scenarios.log
    log ""
    log "Check if QEMU is still running:"
    if [[ -f "$QEMU_PIDFILE" ]] && kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
      log "QEMU process is running (PID $(cat "$QEMU_PIDFILE"))"
      log "Try connecting manually: nc 127.0.0.1 45454"
    else
      log "QEMU process is not running - check the log above for errors"
    fi
    exit 1
  fi
  sleep 1
done

if [[ "$HEADLESS" == "true" ]]; then
  log ""
  log "QEMU is running in background. Connect with VNC viewer to watch:"
  log "  vncviewer ${VNC_BIND_ADDR}:${VNC_PORT}"
else
  log ""
  log "QEMU window is open. Watch the tests run!"
fi

log ""
log "Running shell scenario tests..."
log ""

cd "$PROJECT_ROOT/tests"
export QEMU_MONITOR_ADDR
export VNC_PORT
go test ./cmd -v -run TestShellScenarios
