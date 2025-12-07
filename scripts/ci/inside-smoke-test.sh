#!/usr/bin/env bash
set -euo pipefail

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_SCREENSHOT="${VNC_SCREENSHOT:-qemu-screen-smoke.ppm}"
VNC_CLIENT_LOG="${VNC_CLIENT_LOG:-qemu-vnc-client-smoke.log}"
QEMU_VNC_LOG="${QEMU_VNC_LOG:-qemu-vnc-server.log}"
VNC_CAPTURE_MODE="${VNC_CAPTURE_MODE:-internal}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-5}"
TEMP_VGA=$(mktemp)

go run ./cmd/main.go monitor wait -addr "$QEMU_MONITOR_ADDR" -timeout 15s >/dev/null
go run ./cmd/main.go monitor exec -addr "$QEMU_MONITOR_ADDR" -cmd "xp /4000bx 0xb8000" >"$TEMP_VGA"

VGA_TEXT=$(go run ./cmd/main.go vga extract "$TEMP_VGA")
cp "$TEMP_VGA" qemu-vga-dump.raw.txt
printf "%s\n" "$VGA_TEXT" > qemu-vga-dump.txt

if [[ "$VNC_CAPTURE_MODE" == "internal" ]]; then
  go run ./cmd/main.go vnc capture -addr "$VNC_CONNECT_ADDR" -port "$VNC_PORT" -wait "${VNC_WAIT_SECONDS}s" -output "$VNC_SCREENSHOT" -log "$VNC_CLIENT_LOG"
fi

if [[ "$VGA_TEXT" != *"EnzOS booted successfully."* ]]; then
  echo "Boot message not found in qemu-vga-dump.raw.txt: EnzOS booted successfully." >&2
  exit 1
fi
