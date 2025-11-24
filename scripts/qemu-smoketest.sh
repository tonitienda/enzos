#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="${1:-$REPO_ROOT/enzos.iso}"
LOG_PATH="$REPO_ROOT/qemu-smoketest.log"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-20}"
SUCCESS_PATTERN="EnzOS booted successfully."

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

  if ! timeout "${TIMEOUT_SECONDS}s" \
    qemu-system-x86_64 -cdrom "$ISO_PATH" -serial stdio -no-reboot -no-shutdown -display none \
    | tee "$LOG_PATH"; then
    echo "[qemu-smoketest] QEMU exited with a non-zero status." >&2
    exit 1
  fi
}

assert_boot_message() {
  if grep -Fq "$SUCCESS_PATTERN" "$LOG_PATH"; then
    echo "[qemu-smoketest] Found success pattern: '$SUCCESS_PATTERN'"
    return
  fi

  echo "[qemu-smoketest] Boot message not found in $LOG_PATH" >&2
  exit 1
}

main() {
  require_tools qemu-system-x86_64 timeout tee grep
  ensure_iso_exists
  run_qemu
  assert_boot_message

  echo "[qemu-smoketest] Smoke test passed."
}

main "$@"
