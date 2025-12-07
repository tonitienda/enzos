#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VNC_SCREENSHOT="${VNC_SCREENSHOT:-}"
VNC_CAPTURE_MODE="${VNC_CAPTURE_MODE:-internal}"
VNC_EXTERNAL_CAPTURE_WAIT="${VNC_EXTERNAL_CAPTURE_WAIT:-15}"
VNC_PORT="${VNC_PORT:-1}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-3}"
VNC_BIND_ADDR="${VNC_BIND_ADDR:-0.0.0.0}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_CLIENT_LOG="${VNC_CLIENT_LOG:-qemu-vnc-client.log}"
QEMU_VNC_LOG="${QEMU_VNC_LOG:-qemu-vnc-server.log}"
QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
QEMU_KEEP_ALIVE="${QEMU_KEEP_ALIVE:-false}"
VGA_BOOT_WAIT="${VGA_BOOT_WAIT:-2}"
QEMU_PIDFILE="${QEMU_PIDFILE:-$(mktemp)}"

log() {
  printf '[qemu-smoketest] %s\n' "$*" >&2
}

go_tool() {
  (cd "$PROJECT_ROOT" && go run ./cmd/main.go "$@")
}

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  log "qemu-system-x86_64 is required to run this test."
  exit 1
fi

cleanup() {
  [[ -n "${VGA_DUMP_TMP:-}" && -f "$VGA_DUMP_TMP" ]] && rm -f "$VGA_DUMP_TMP"

  if [[ "$QEMU_KEEP_ALIVE" != "true" && -f "$QEMU_PIDFILE" ]]; then
    if kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
      kill "$(cat "$QEMU_PIDFILE")" 2>/dev/null || true
    fi
    rm -f "$QEMU_PIDFILE"
  fi
}
trap cleanup EXIT

VGA_DUMP_TMP="$(mktemp)"
VGA_RAW_OUT="${VGA_RAW_OUT:-qemu-vga-dump.raw.txt}"
VGA_TEXT_OUT="${VGA_TEXT_OUT:-qemu-vga-dump.txt}"
VGA_BOOT_MESSAGE="EnzOS booted successfully."

rm -f "$VGA_RAW_OUT" "$VGA_TEXT_OUT"

wait_for_monitor() {
  local attempts=20
  for ((i = 1; i <= attempts; i++)); do
    if go_tool monitor wait -addr "$QEMU_MONITOR_ADDR" -timeout 2s; then
      return 0
    fi

    sleep 1
  done

  log "Timed out waiting for QEMU monitor at ${QEMU_MONITOR_ADDR}."
  log "QEMU VNC log saved to: $QEMU_VNC_LOG"
  exit 1
}

run_monitor_command() {
  local command="$1"
  go_tool monitor exec -addr "$QEMU_MONITOR_ADDR" -cmd "$command"
}

start_qemu() {
  : >"$QEMU_VNC_LOG"
  log "Starting QEMU with monitor ${QEMU_MONITOR_ADDR} and VNC on ${VNC_BIND_ADDR}:${VNC_PORT}."
  if ! qemu-system-x86_64 -cdrom "$ISO_PATH" -display none -serial none -parallel none -no-reboot -no-shutdown \
      -daemonize -pidfile "$QEMU_PIDFILE" -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
      -vnc "${VNC_BIND_ADDR}:${VNC_PORT}" >"$QEMU_VNC_LOG" 2>&1; then
    log "Failed to start QEMU with VNC enabled; see $QEMU_VNC_LOG for details."
    exit 1
  fi

  if [[ ! -s "$QEMU_PIDFILE" ]]; then
    log "QEMU pidfile not created; QEMU may have failed to start."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    exit 1
  fi

  wait_for_monitor
}

shutdown_qemu() {
  if [[ -f "$QEMU_PIDFILE" && -s "$QEMU_PIDFILE" ]]; then
    run_monitor_command "quit" >/dev/null 2>&1 || true
  fi
}

capture_vga_dump() {
  sleep "$VGA_BOOT_WAIT"
  run_monitor_command "xp /4000bx 0xb8000" >"$VGA_DUMP_TMP"

  VGA_TEXT=$(go_tool vga extract "$VGA_DUMP_TMP")
  cp "$VGA_DUMP_TMP" "$VGA_RAW_OUT"
  printf "%s\n" "$VGA_TEXT" >"$VGA_TEXT_OUT"
  chmod 644 "$VGA_RAW_OUT" "$VGA_TEXT_OUT"
}

capture_vnc_screenshot() {
  if [[ -z "$VNC_SCREENSHOT" ]]; then
    log "VNC_SCREENSHOT not set; skipping VNC screenshot capture."
    return
  fi

  local vnc_tcp_port=$((5900 + VNC_PORT))
  log "Capturing VNC screenshot to ${VNC_SCREENSHOT} (display ${vnc_tcp_port}, mode ${VNC_CAPTURE_MODE})."

  if [[ "$VNC_CAPTURE_MODE" == "external" ]]; then
    log "External VNC capture requested; skipping vncsnapshot inside the container."
    log "Connect from the host while QEMU runs:"
    log "  vncsnapshot ${VNC_CONNECT_ADDR}:${VNC_PORT} ${VNC_SCREENSHOT}"
    log "Waiting ${VNC_EXTERNAL_CAPTURE_WAIT}s before resuming the workflow."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    sleep "$VNC_EXTERNAL_CAPTURE_WAIT"
    return
  fi

  if ! go_tool vnc capture -addr "$VNC_CONNECT_ADDR" -port "$VNC_PORT" -wait "${VNC_WAIT_SECONDS}s" -output "$VNC_SCREENSHOT" -log "$VNC_CLIENT_LOG"; then
    log "VNC capture failed; see $VNC_CLIENT_LOG"
    if [[ -f "$VNC_CLIENT_LOG" ]]; then
      cat "$VNC_CLIENT_LOG" >&2 || true
    fi
    return
  fi

  log "Saved VNC screenshot to: $VNC_SCREENSHOT"
  log "vncsnapshot log saved to: $VNC_CLIENT_LOG"
}

start_qemu
capture_vga_dump

if [[ "$VGA_TEXT" == *"$VGA_BOOT_MESSAGE"* ]]; then
  log "VGA boot message detected."
  capture_vnc_screenshot

  if [[ "$QEMU_KEEP_ALIVE" == "true" ]]; then
    log "Leaving QEMU running for follow-up integration tests (pidfile: $QEMU_PIDFILE)."
    exit 0
  fi

  shutdown_qemu
  exit 0
fi

capture_vnc_screenshot
shutdown_qemu

log "Failed to find VGA boot message in QEMU output."
log "VGA text dump follows:"
log "${VGA_TEXT:-<empty>}" >&2
log "Saved raw monitor output to: $VGA_RAW_OUT"
log "Saved parsed VGA text to: $VGA_TEXT_OUT"
exit 1
