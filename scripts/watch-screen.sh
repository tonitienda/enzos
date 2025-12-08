#!/usr/bin/env bash
# Continuously watch the QEMU VGA screen while tests are running

set -euo pipefail

MONITOR_ADDR="${QEMU_MONITOR_ADDR:-127.0.0.1:45454}"

echo "Watching QEMU VGA screen (press Ctrl+C to stop)..."
echo "Connect to monitor at $MONITOR_ADDR"
echo ""

while true; do
    clear
    echo "=== QEMU VGA SCREEN CONTENT (live) ==="
    echo ""
    
    # Read VGA buffer and parse it
    (
        echo "xp/4000xb 0xb8000"
        sleep 0.1
    ) | nc -w 1 "$MONITOR_ADDR" 2>/dev/null | \
        grep -E "^0x[0-9a-f]+:" | \
        sed 's/^[^:]*: //' | \
        grep -oE "0x[0-9a-f]{2}" | \
        sed 's/0x//' | \
        xxd -r -p | \
        sed 's/\x00//g' | \
        fold -w 80 || echo "(waiting for QEMU...)"
    
    echo ""
    echo "=== Press Ctrl+C to stop ==="
    sleep 0.5
done
