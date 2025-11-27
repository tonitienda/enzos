#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VNC_SCREENSHOT="${VNC_SCREENSHOT:-}"
VNC_CAPTURE_MODE="${VNC_CAPTURE_MODE:-internal}"
VNC_EXTERNAL_CAPTURE_WAIT="${VNC_EXTERNAL_CAPTURE_WAIT:-15}"
VNC_PORT="${VNC_PORT:-1}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-3}"
VNC_BIND_ADDR="${VNC_BIND_ADDR:-0.0.0.0}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_CLIENT_LOG="${VNC_CLIENT_LOG:-qemu-vnc-client.log}"
QEMU_VNC_LOG="${QEMU_VNC_LOG:-qemu-vnc-server.log}"
VNC_PIDFILE=""

log() {
  printf '[qemu-smoketest] %s\n' "$*" >&2
}

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  log "qemu-system-x86_64 is required to run this test."
  exit 1
fi

if [[ -n "$VNC_SCREENSHOT" && "$VNC_CAPTURE_MODE" == "internal" ]] && ! command -v vncsnapshot >/dev/null 2>&1; then
  log "vncsnapshot is required when VNC_SCREENSHOT is set and VNC_CAPTURE_MODE=internal."
  exit 1
fi

cleanup() {
  [[ -n "${VGA_DUMP_TMP:-}" && -f "$VGA_DUMP_TMP" ]] && rm -f "$VGA_DUMP_TMP"
  if [[ -n "$VNC_PIDFILE" && -f "$VNC_PIDFILE" ]]; then
    if kill -0 "$(cat "$VNC_PIDFILE")" 2>/dev/null; then
      kill "$(cat "$VNC_PIDFILE")" 2>/dev/null || true
    fi
    rm -f "$VNC_PIDFILE"
  fi
}
trap cleanup EXIT

VGA_DUMP_TMP="$(mktemp)"
VGA_RAW_OUT="${VGA_RAW_OUT:-qemu-vga-dump.raw.txt}"
VGA_TEXT_OUT="${VGA_TEXT_OUT:-qemu-vga-dump.txt}"

rm -f "$VGA_RAW_OUT" "$VGA_TEXT_OUT"

# Dump VGA text memory via the QEMU monitor. We wait briefly for the guest to boot
# before sampling the buffer to give the kernel time to paint the screen.
# The VGA text buffer lives at 0xB8000 and uses one byte for the character and one
# byte for the attribute, so we read 4000 bytes (80x25x2) and filter out the
# attribute bytes below.
timeout 20s bash -c "{
        sleep 2
        echo 'xp /4000bx 0xb8000'
        sleep 1
        echo 'quit'
} | qemu-system-x86_64 -cdrom \"$ISO_PATH\" -monitor stdio -serial none -parallel none -display none -no-reboot -no-shutdown" >"$VGA_DUMP_TMP"

# Extract printable characters from the dump: every even-positioned byte is a
# character, and the odd-positioned bytes are color attributes.
VGA_TEXT=$(go run "$SCRIPT_DIR/qemu_vga_extract.go" "$VGA_DUMP_TMP")

capture_vnc_screenshot() {
  if [[ -z "$VNC_SCREENSHOT" ]]; then
    log "VNC_SCREENSHOT not set; skipping VNC screenshot capture."
    return
  fi

  local vnc_tcp_port=$((5900 + VNC_PORT))
  log "Capturing VNC screenshot to ${VNC_SCREENSHOT} (display ${vnc_tcp_port}, bind ${VNC_BIND_ADDR}, mode ${VNC_CAPTURE_MODE})..."
  : >"$QEMU_VNC_LOG"
  VNC_PIDFILE="$(mktemp)"
  if ! qemu-system-x86_64 -cdrom "$ISO_PATH" -display none -serial none -parallel none -no-reboot -no-shutdown \
      -daemonize -pidfile "$VNC_PIDFILE" -vnc "${VNC_BIND_ADDR}:${VNC_PORT}" >"$QEMU_VNC_LOG" 2>&1; then
    log "Failed to start QEMU with VNC enabled; skipping screenshot."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    return 1
  fi

  if [[ ! -s "$VNC_PIDFILE" ]]; then
    log "VNC pidfile not created; QEMU may have failed to start."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    return 1
  fi

  if ! kill -0 "$(cat "$VNC_PIDFILE")" 2>/dev/null; then
    log "QEMU process from pidfile is not running; cannot reach VNC server."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    return 1
  fi

  if [[ "$VNC_CAPTURE_MODE" == "external" ]]; then
    log "External VNC capture requested; skipping vncsnapshot inside the container."
    log "Connect from the host while QEMU runs:"
    log "  vncsnapshot ${VNC_CONNECT_ADDR}:${VNC_PORT} ${VNC_SCREENSHOT}"
    log "Waiting ${VNC_EXTERNAL_CAPTURE_WAIT}s before tearing down VNC so the runner can snapshot and upload to the PR."
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    sleep "$VNC_EXTERNAL_CAPTURE_WAIT"
  else
    log "Waiting ${VNC_WAIT_SECONDS}s before attempting vncsnapshot; connect from the host with:"
    log "  vncsnapshot ${VNC_CONNECT_ADDR}:${VNC_PORT} out.ppm"
    log "QEMU VNC log saved to: $QEMU_VNC_LOG"
    sleep "$VNC_WAIT_SECONDS"
    : >"$VNC_CLIENT_LOG"
    if ! vncsnapshot -quiet "${VNC_CONNECT_ADDR}:${VNC_PORT}" "$VNC_SCREENSHOT" >"$VNC_CLIENT_LOG" 2>&1; then
      local status=$?
      log "vncsnapshot failed with exit code ${status}; output follows:"
      cat "$VNC_CLIENT_LOG" >&2
      log "vncsnapshot log saved to: $VNC_CLIENT_LOG"
    else
      chmod 644 "$VNC_SCREENSHOT"
      log "Saved VNC screenshot to: $VNC_SCREENSHOT"
      log "vncsnapshot log saved to: $VNC_CLIENT_LOG"
    fi
  fi
}

if [[ "$VGA_TEXT" == *"EnzOS booted successfully."* ]]; then
  log "VGA boot message detected."
  capture_vnc_screenshot
  exit 0
fi

cp "$VGA_DUMP_TMP" "$VGA_RAW_OUT"
printf "%s\n" "$VGA_TEXT" >"$VGA_TEXT_OUT"
chmod 644 "$VGA_RAW_OUT" "$VGA_TEXT_OUT"

capture_vnc_screenshot

log "Failed to find VGA boot message in QEMU output."
log "VGA text dump follows:"
echo "${VGA_TEXT:-<empty>}" >&2
log "Saved raw monitor output to: $VGA_RAW_OUT"
log "Saved parsed VGA text to: $VGA_TEXT_OUT"
exit 1
