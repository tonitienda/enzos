#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "[qemu-smoketest] qemu-system-x86_64 is required to run this test." >&2
        exit 1
fi

cleanup() {
        [[ -n "${VGA_DUMP:-}" && -f "$VGA_DUMP" ]] && rm -f "$VGA_DUMP"
}
trap cleanup EXIT

VGA_DUMP="$(mktemp)"

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
} | qemu-system-x86_64 -cdrom \"$ISO_PATH\" -monitor stdio -serial none -parallel none -display none -no-reboot -no-shutdown" >"$VGA_DUMP"

# Extract printable characters from the dump: every even-positioned byte is a
# character, and the odd-positioned bytes are color attributes.
VGA_TEXT=$(go run "$SCRIPT_DIR/qemu_vga_extract.go" "$VGA_DUMP")

if [[ "$VGA_TEXT" == *"EnzOS booted successfully."* ]]; then
        echo "[qemu-smoketest] VGA boot message detected."
        exit 0
fi

echo "[qemu-smoketest] Failed to find VGA boot message in QEMU output." >&2
exit 1
