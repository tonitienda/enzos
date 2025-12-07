#!/usr/bin/env bash
set -euo pipefail

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
QEMU_VNC_LOG="${QEMU_VNC_LOG:-qemu-vnc-server-integration.log}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-2}"

capture_integration_images() {
  set +e

  echo "[integration-test] Replaying echo scenario for terminal screenshot." >&2
  local keys=(
    "e" "c" "h" "o" "spc"
    "shift-apostrophe"
    "shift-h" "e" "l" "l" "o" "comma" "spc"
    "shift-w" "o" "r" "l" "d"
    "shift-apostrophe" "ret"
  )

  : > /tmp/integration-terminal-setup.log
  for key in "${keys[@]}"; do
    if ! go run ./cmd/main.go monitor exec -addr "$QEMU_MONITOR_ADDR" -cmd "sendkey $key" >>/tmp/integration-terminal-setup.log 2>&1; then
      echo "[integration-test] Unable to send key '$key' to QEMU; screenshot may not show expected prompt." >&2
      break
    fi
    sleep 0.1
  done

  echo "[integration-test] Capturing first integration screenshot (post-test state)..." >&2
  VNC_SCREENSHOT=qemu-screen-integration.ppm VNC_CLIENT_LOG=qemu-vnc-client-integration.log \
    go run ./cmd/main.go vnc capture -addr "$VNC_CONNECT_ADDR" -port "$VNC_PORT" -wait "${VNC_WAIT_SECONDS}s" -output qemu-screen-integration.ppm -log qemu-vnc-client-integration.log || true

  echo "[integration-test] Capturing second integration screenshot (terminal with longer wait)..." >&2
  go run ./cmd/main.go vnc capture -addr "$VNC_CONNECT_ADDR" -port "$VNC_PORT" -wait 3s -output qemu-screen-integration-terminal.ppm -log qemu-vnc-client-integration-terminal.log || true

  set -e
}

go run ./cmd/main.go monitor wait -addr "$QEMU_MONITOR_ADDR" -timeout 15s >/dev/null

if [[ -n "$QEMU_PIDFILE" && ! -f "$QEMU_PIDFILE" ]]; then
  echo "QEMU pidfile missing at $QEMU_PIDFILE; cannot run integration tests." >&2
  exit 1
fi

if ! kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
  echo "QEMU process not running after boot (pidfile: $QEMU_PIDFILE)." >&2
  exit 1
fi

set +e
go test ./cmd -count=1 -v -test.timeout=5m
test_status=$?
set -e

trap 'capture_integration_images' EXIT

exit "$test_status"
