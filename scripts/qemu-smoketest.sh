#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="${1:-$REPO_ROOT/enzos.iso}"
LOG_PATH="$REPO_ROOT/qemu-smoketest.log"
VRAM_DUMP_PATH="$REPO_ROOT/qemu-smoketest.vram"
QMP_SOCKET_PATH="$REPO_ROOT/qemu-smoketest.qmp"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"
SUCCESS_PATTERN="EnzOS booted successfully."
QEMU_LOG_FLAGS=(-d guest_errors,int -msg timestamp=on)
QEMU_PID=0
QEMU_STATUS=0

require_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if ((${#missing[@]} > 0)); then
    echo "[qemu-smoketest] Missing tools: ${missing[*]}" >&2
    echo "[qemu-smoketest] Install dependencies or run inside the project Docker image." >&2
    exit 1
  fi
}

ensure_iso_exists() {
  if [ ! -f "$ISO_PATH" ]; then
    echo "[qemu-smoketest] ISO not found at $ISO_PATH" >&2
    echo "[qemu-smoketest] Build it with scripts/build-iso.sh first." >&2
    exit 1
  fi
}

run_qemu() {
  echo "[qemu-smoketest] Booting $ISO_PATH in QEMU (timeout: ${TIMEOUT_SECONDS}s)..."
  : > "$LOG_PATH"
  rm -f "$VRAM_DUMP_PATH" "$QMP_SOCKET_PATH"

  qemu-system-x86_64 -cdrom "$ISO_PATH" -serial file:"$LOG_PATH" -no-reboot -no-shutdown \
    -display none "${QEMU_LOG_FLAGS[@]}" -qmp unix:"$QMP_SOCKET_PATH",server,wait=off &
  QEMU_PID=$!
}

wait_for_qmp() {
  local waited=0
  while ((waited < TIMEOUT_SECONDS)); do
    if [ -S "$QMP_SOCKET_PATH" ]; then
      return
    fi

    if ! kill -0 "$QEMU_PID" >/dev/null 2>&1; then
      echo "[qemu-smoketest] QEMU exited before QMP socket became available." >&2
      exit 1
    fi

    sleep 1
    ((waited++))
  done

  echo "[qemu-smoketest] Timed out waiting for QMP socket at $QMP_SOCKET_PATH." >&2
  kill "$QEMU_PID" >/dev/null 2>&1 || true
  exit 1
}

dump_vram_and_shutdown() {
  python3 "$REPO_ROOT/scripts/qemu_vga_tools.py" dump "$QMP_SOCKET_PATH" "$VRAM_DUMP_PATH"
}

wait_for_qemu_exit() {
  local waited=0
  while kill -0 "$QEMU_PID" >/dev/null 2>&1; do
    if ((waited >= TIMEOUT_SECONDS)); then
      echo "[qemu-smoketest] QEMU did not exit within ${TIMEOUT_SECONDS}s; terminating." >&2
      kill "$QEMU_PID" >/dev/null 2>&1 || true
      break
    fi

    sleep 1
    ((waited++))
  done

  if wait "$QEMU_PID" >/dev/null 2>&1; then
    QEMU_STATUS=0
  else
    QEMU_STATUS=$?
  fi
}

assert_boot_message() {
  if [ ! -f "$VRAM_DUMP_PATH" ]; then
    echo "[qemu-smoketest] VGA dump not found at $VRAM_DUMP_PATH." >&2
    exit 1
  fi

  if python3 "$REPO_ROOT/scripts/qemu_vga_tools.py" assert "$SUCCESS_PATTERN" "$VRAM_DUMP_PATH"
  then
    return
  fi

  echo "[qemu-smoketest] Boot message not found in VGA text (QEMU exit status: $QEMU_STATUS)" >&2
  exit 1
}

main() {
  require_tools qemu-system-x86_64 python3
  ensure_iso_exists
  run_qemu
  wait_for_qmp
  dump_vram_and_shutdown
  wait_for_qemu_exit
  assert_boot_message

  echo "[qemu-smoketest] Smoke test passed."
}

main "$@"
