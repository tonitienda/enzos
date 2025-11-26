#!/usr/bin/env python3
"""Extract printable VGA text characters from a QEMU monitor dump.

The QEMU monitor dump lists bytes as two-digit hex values. The VGA text buffer
uses pairs of bytes per cell: the character byte followed by an attribute byte.
This script keeps the character bytes and drops the attributes, mirroring the
logic in `qemu-smoketest.sh`.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def extract_characters(dump_path: Path) -> str:
    """Return printable characters from a VGA dump file."""
    hex_pairs: list[str] = []
    for line in dump_path.read_text().splitlines():
        # Lines with memory contents look like: "0000b8000: 48 1f 65 1f".
        # Extract all two-digit hex bytes, ignoring addresses and separators.
        hex_pairs.extend(re.findall(r"0x?([0-9a-fA-F]{2})", line))

    chars: list[str] = []
    for index, byte_hex in enumerate(hex_pairs):
        if index % 2 != 0:
            continue  # Skip attribute bytes.
        if byte_hex == "00":
            continue
        chars.append(chr(int(byte_hex, 16)))

    return "".join(chars)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: qemu_vga_extract.py <dump_path>\n")
        return 1

    dump_path = Path(argv[1])
    if not dump_path.exists():
        sys.stderr.write(f"dump file not found: {dump_path}\n")
        return 1

    print(extract_characters(dump_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
