#!/usr/bin/env bash
set -euo pipefail

QEMU_MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"
VNC_PORT="${VNC_PORT:-1}"
VNC_CONNECT_ADDR="${VNC_CONNECT_ADDR:-127.0.0.1}"
VNC_WAIT_SECONDS="${VNC_WAIT_SECONDS:-5}"

export QEMU_MONITOR_ADDR
export VNC_PORT
export VNC_CONNECT_ADDR
export VNC_WAIT_SECONDS

go test ./cmd -count=1 -run TestOSIsReady -test.v
