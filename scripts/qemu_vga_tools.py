#!/usr/bin/env python3
import argparse
import json
import socket
import sys
from pathlib import Path


def recv_message(sock: socket.socket) -> bytes:
    data = b""
    while not data.endswith(b"\r\n"):
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def send_command(sock: socket.socket, command: dict) -> bytes:
    payload = json.dumps(command) + "\r\n"
    sock.sendall(payload.encode())
    return recv_message(sock)


def dump_vram(qmp_socket: str, dump_path: str) -> int:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(qmp_socket)
        recv_message(sock)
        send_command(sock, {"execute": "qmp_capabilities"})
        send_command(
            sock,
            {
                "execute": "human-monitor-command",
                "arguments": {
                    "command-line": f"pmemsave 0xb8000 4000 {dump_path}"
                },
            },
        )
        send_command(sock, {"execute": "quit"})

    if not Path(dump_path).exists():
        print("Failed to dump VGA text buffer.", file=sys.stderr)
        return 1

    return 0


def assert_boot_message(pattern: str, dump_path: str) -> int:
    data = Path(dump_path).read_bytes()
    chars = data[0::2]
    text = bytes(c for c in chars if c != 0).decode("ascii", errors="ignore")

    if pattern in text:
        print(f"[qemu-smoketest] Found success pattern in VGA text: '{pattern}'")
        return 0

    preview = text.strip().split("\n")
    preview_line = preview[0] if preview else ""
    print(
        f"[qemu-smoketest] VGA text did not contain pattern. First line: '{preview_line}'",
        file=sys.stderr,
    )
    return 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="QEMU VGA helper tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    dump_parser = subparsers.add_parser("dump", help="Dump VGA text buffer via QMP")
    dump_parser.add_argument("qmp_socket", help="Path to QMP socket")
    dump_parser.add_argument("dump_path", help="Output path for VGA dump")

    assert_parser = subparsers.add_parser(
        "assert", help="Check the VGA dump for a success pattern"
    )
    assert_parser.add_argument("pattern", help="String to search for in VGA text")
    assert_parser.add_argument("dump_path", help="Path to VGA dump file")

    args = parser.parse_args(argv)

    if args.command == "dump":
        return dump_vram(args.qmp_socket, args.dump_path)
    if args.command == "assert":
        return assert_boot_message(args.pattern, args.dump_path)

    parser.error("Unknown command")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
