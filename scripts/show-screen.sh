#!/usr/bin/env bash
# Show what's currently visible on the QEMU VGA screen

set -euo pipefail

MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"

echo "Reading VGA buffer from QEMU monitor at $MONITOR_ADDR..."
echo ""
echo "=== CURRENT SCREEN CONTENT ==="
echo ""

# Connect to QEMU monitor and read VGA buffer
# VGA text mode: 80x25 characters, 2 bytes per char (char + attribute)
# Total: 4000 bytes
(
    echo "xp/4000xb 0xb8000"
    sleep 0.5
) | nc "$MONITOR_ADDR" 2>/dev/null | \
    grep -E "^0x[0-9a-f]+:" | \
    sed 's/^[^:]*: //' | \
    grep -oE "0x[0-9a-f]{2}" | \
    sed 's/0x//' | \
    xxd -r -p | \
    sed 's/\x00//g' | \
    fold -w 80

echo ""
echo "=== END SCREEN ===" 
