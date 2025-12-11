#!/usr/bin/env bash
# Simple script to run shell scenario tests with QEMU
# Usage: ./scripts/run-shell-scenarios-simple.sh [--headless]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISO_PATH="${ISO_PATH:-$PROJECT_ROOT/os/enzos.iso}"
QEMU_MONITOR_ADDR="127.0.0.1:45454"
HEADLESS="${HEADLESS:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --headless)
      HEADLESS=true
      ;;
  esac
done

log() {
  printf '[shell-scenarios] %s\n' "$*" >&2
}

if [[ ! -f "$ISO_PATH" ]]; then
  log "ISO not found at $ISO_PATH"
  log "Build it first with: just build-iso"
  exit 1
fi

log "Using ISO: $ISO_PATH"

# Clean up any existing QEMU processes
pkill -f "qemu-system.*${ISO_PATH##*/}" 2>/dev/null || true
sleep 1

if [[ "$HEADLESS" == "true" ]]; then
  log "Starting QEMU in headless mode..."
  DISPLAY_ARG="-display none"
else
  log "Starting QEMU with visible window..."
  log "The QEMU window will open - watch the tests run!"
  log "Look for a window titled 'QEMU' that appears!"
  DISPLAY_ARG=""
fi
log ""

# Start QEMU in background
qemu-system-x86_64 \
  -cdrom "$ISO_PATH" \
  -no-reboot \
  -no-shutdown \
  -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
  $DISPLAY_ARG \
  &

QEMU_PID=$!
log "QEMU started with PID $QEMU_PID"

# Check if QEMU process is actually running
sleep 1
if ! kill -0 $QEMU_PID 2>/dev/null; then
  log "ERROR: QEMU process died immediately after start"
  wait $QEMU_PID 2>/dev/null || true
  exit 1
fi

# Wait for QEMU to initialize and monitor to be ready
log "Waiting for QEMU monitor..."
for i in {1..30}; do
  # Try to connect using available tools (nc, timeout+echo, or Go)
  if command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 45454 2>/dev/null; then
      log "Monitor is ready!"
      break
    fi
  else
    # Fallback: try to connect with timeout
    if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/45454" 2>/dev/null; then
      log "Monitor is ready!"
      break
    fi
  fi
  
  if [[ $i -eq 30 ]]; then
    log "Monitor didn't start in time"
    kill $QEMU_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

if [[ "$SKIP_TESTS" != "true" ]]; then

  log ""
  log "Running tests..."
  log ""

  cd "$PROJECT_ROOT/tests"
  export QEMU_MONITOR_ADDR
  export SCREENSHOT_DIR="$PROJECT_ROOT"

  # Enable demo mode (slower execution) when not headless
  if [[ "$HEADLESS" != "true" ]]; then
    export DEMO_MODE=1
    log "Demo mode enabled: tests will run slowly for visibility"
    log ""
  fi

  go test ./cmd -v -run TestShellScenarios -count=1

  TEST_EXIT=$?

  log ""
  if [[ "$HEADLESS" == "true" ]]; then
    log "Tests completed. Stopping QEMU..."
    kill $QEMU_PID 2>/dev/null || true
  else
    log "Tests completed!"
    log "QEMU window is still open (PID $QEMU_PID)"
    log "Close the window manually or press Ctrl+C to exit"
    wait $QEMU_PID 2>/dev/null || true
  fi

  exit $TEST_EXIT
fi