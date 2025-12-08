#!/usr/bin/env bash
set -euo pipefail

# Start QEMU in background and keep container alive
# Tests will connect to this running QEMU instance

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
VNC_PORT="${VNC_PORT:-1}"
QEMU_PIDFILE="${QEMU_PIDFILE:-/tmp/qemu-ci.pid}"

echo "Starting QEMU with monitor on $QEMU_MONITOR_ADDR and VNC port $VNC_PORT..."

qemu-system-x86_64 \
  -cdrom /src/enzos.iso \
  -serial none \
  -no-reboot \
  -no-shutdown \
  -monitor "tcp:${QEMU_MONITOR_ADDR},server=on,wait=off" \
  -display none \
  &

QEMU_PID=$!
echo "$QEMU_PID" > "$QEMU_PIDFILE"
echo "QEMU started with PID $QEMU_PID"

# Keep container alive
tail -f /dev/null
