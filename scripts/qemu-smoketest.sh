#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-enzos.iso}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "[qemu-smoketest] qemu-system-x86_64 is required to run this test." >&2
        exit 1
fi

cleanup() {
        [[ -n "${VGA_DUMP_TMP:-}" && -f "$VGA_DUMP_TMP" ]] && rm -f "$VGA_DUMP_TMP"
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

if [[ "$VGA_TEXT" == *"EnzOS booted successfully."* ]]; then
        echo "[qemu-smoketest] VGA boot message detected."
        exit 0
fi

cp "$VGA_DUMP_TMP" "$VGA_RAW_OUT"
printf "%s\n" "$VGA_TEXT" >"$VGA_TEXT_OUT"

echo "[qemu-smoketest] Failed to find VGA boot message in QEMU output." >&2
echo "[qemu-smoketest] VGA text dump follows:" >&2
echo "${VGA_TEXT:-<empty>}" >&2
echo "[qemu-smoketest] Saved raw monitor output to: $VGA_RAW_OUT" >&2
echo "[qemu-smoketest] Saved parsed VGA text to: $VGA_TEXT_OUT" >&2
exit 1
