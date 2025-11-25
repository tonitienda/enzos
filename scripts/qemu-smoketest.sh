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
  python3 - "$QMP_SOCKET_PATH" "$VRAM_DUMP_PATH" <<'PY'
import json
import socket
import sys
from pathlib import Path

qmp_socket, dump_path = sys.argv[1:]

def recv_message(sock):
    data = b""
    while not data.endswith(b"\r\n"):
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    return data

def send_command(sock, command):
    payload = json.dumps(command) + "\r\n"
    sock.sendall(payload.encode())
    return recv_message(sock)

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
    sock.connect(qmp_socket)
    recv_message(sock)
    send_command(sock, {"execute": "qmp_capabilities"})
    send_command(
        sock,
        {
            "execute": "human-monitor-command",
            "arguments": {"command-line": f"pmemsave 0xb8000 4000 {dump_path}"},
        },
    )
    send_command(sock, {"execute": "quit"})

if not Path(dump_path).exists():
    sys.exit("Failed to dump VGA text buffer.")
PY
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

  if python3 - "$SUCCESS_PATTERN" "$VRAM_DUMP_PATH" <<'PY'; then
import sys
from pathlib import Path

pattern, dump_path = sys.argv[1:3]
data = Path(dump_path).read_bytes()
chars = data[0::2]
text = bytes(c for c in chars if c != 0).decode("ascii", errors="ignore")
if pattern in text:
    print(f"[qemu-smoketest] Found success pattern in VGA text: '{pattern}'")
    sys.exit(0)

preview = text.strip().split("\n")
preview_line = preview[0] if preview else ""
print(f"[qemu-smoketest] VGA text did not contain pattern. First line: '{preview_line}'")
sys.exit(1)
PY
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
