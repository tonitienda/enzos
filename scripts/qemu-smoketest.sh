#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VNC_SCREENSHOT="${VNC_SCREENSHOT:-}"
VNC_PORT="${VNC_PORT:-1}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-3}"
VNC_PIDFILE=""

log() {
  printf '[qemu-smoketest] %s\n' "$*" >&2
}

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  log "qemu-system-x86_64 is required to run this test."
  exit 1
fi

if [[ -n "$VNC_SCREENSHOT" ]] && ! command -v vncsnapshot >/dev/null 2>&1; then
  log "vncsnapshot is required when VNC_SCREENSHOT is set."
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

  log "Capturing VNC screenshot to ${VNC_SCREENSHOT} (port ${VNC_PORT})..."
  VNC_PIDFILE="$(mktemp)"
  if ! qemu-system-x86_64 -cdrom "$ISO_PATH" -display none -serial none -parallel none -no-reboot -no-shutdown \
      -daemonize -pidfile "$VNC_PIDFILE" -vnc "127.0.0.1:${VNC_PORT}" >/dev/null 2>&1; then
    log "Failed to start QEMU with VNC enabled; skipping screenshot."
    return 1
  fi

  if [[ ! -s "$VNC_PIDFILE" ]]; then
    log "VNC pidfile not created; QEMU may have failed to start."
    return 1
  fi

  if ! kill -0 "$(cat "$VNC_PIDFILE")" 2>/dev/null; then
    log "QEMU process from pidfile is not running; cannot reach VNC server."
    return 1
  fi

  log "Waiting ${VNC_WAIT_SECONDS}s before attempting vncsnapshot..."
  sleep "$VNC_WAIT_SECONDS"
  VNC_OUTPUT_LOG="$(mktemp)"
  if ! vncsnapshot -quiet "127.0.0.1:${VNC_PORT}" "$VNC_SCREENSHOT" >"$VNC_OUTPUT_LOG" 2>&1; then
    local status=$?
    log "vncsnapshot failed with exit code ${status}; output follows:"
    cat "$VNC_OUTPUT_LOG" >&2
  else
    chmod 644 "$VNC_SCREENSHOT"
    log "Saved VNC screenshot to: $VNC_SCREENSHOT"
  fi
  rm -f "$VNC_OUTPUT_LOG"
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
