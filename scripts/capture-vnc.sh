#!/usr/bin/env bash
set -euo pipefail

VNC_SCREENSHOT="${VNC_SCREENSHOT:-}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CLIENT_LOG="${VNC_CLIENT_LOG:-qemu-vnc-client.log}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-2}"

log() {
  printf '[capture-vnc] %s\n' "$*" >&2
}

if [[ -z "$VNC_SCREENSHOT" ]]; then
  log "VNC_SCREENSHOT is required to capture a screenshot."
  exit 1
fi

if ! command -v vncsnapshot >/dev/null 2>&1; then
  log "vncsnapshot is required to capture screenshots."
  exit 1
fi

log "Capturing VNC screenshot to ${VNC_SCREENSHOT} from ${VNC_CONNECT_ADDR}:${VNC_PORT}."
log "Waiting ${VNC_WAIT_SECONDS}s so the guest can paint the screen."
sleep "$VNC_WAIT_SECONDS"

: >"$VNC_CLIENT_LOG"
if ! vncsnapshot -quiet "${VNC_CONNECT_ADDR}:${VNC_PORT}" "$VNC_SCREENSHOT" >"$VNC_CLIENT_LOG" 2>&1; then
  status=$?
  log "vncsnapshot failed with exit code ${status}; output follows:"
  cat "$VNC_CLIENT_LOG" >&2
  log "vncsnapshot log saved to: $VNC_CLIENT_LOG"
  exit "$status"
fi

chmod 644 "$VNC_SCREENSHOT"
log "Saved VNC screenshot to: $VNC_SCREENSHOT"
log "vncsnapshot log saved to: $VNC_CLIENT_LOG"
