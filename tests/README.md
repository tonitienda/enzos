# Running Shell Scenario Tests

## Quick Start

The easiest way to run the shell scenario tests is to use the provided script:

```bash
./scripts/integration-test.sh
```

Or run in headless mode:

```bash
./scripts/integration-test.sh --headless
```

This script will:

1. Start QEMU with the EnzOS ISO (visible window or headless)
2. Enable the QEMU monitor on `127.0.0.1:45454`
3. Run the shell scenario tests
4. Capture screenshots during tests
5. Clean up QEMU when done

## Manual Setup

If you prefer to start QEMU manually, follow these steps:

### 1. Build the ISO

```bash
just build-iso
# or
./scripts/build-iso.sh
```

### 2. Start QEMU with monitor and VNC

```bash
qemu-system-x86_64 \
  -cdrom enzos.iso \
  -serial none \
  -no-reboot \
  -no-shutdown \
  -monitor tcp:127.0.0.1:45454,server=on,wait=off \
  -vnc 127.0.0.1:1 \
  -daemonize \
  -pidfile /tmp/enzos-qemu.pid
```

Key parameters:

- `-monitor tcp:127.0.0.1:45454,server=on,wait=off` - Opens QEMU monitor on TCP port 45454
- `-vnc 127.0.0.1:1` - Opens VNC server on port 5901 (display number 1)
- `-daemonize` - Runs QEMU in background
- `-pidfile /tmp/enzos-qemu.pid` - Saves process ID for cleanup

### 3. Run the tests

```bash
cd tests
export QEMU_MONITOR_ADDR=127.0.0.1:45454
export VNC_PORT=1
go test ./cmd -v -run TestShellScenarios
```

### 4. Watch the tests (optional)

While tests are running, you can connect with a VNC viewer to see what's happening:

```bash
vncviewer 127.0.0.1:1
# or
open vnc://127.0.0.1:5901
```

### 5. Cleanup

```bash
kill $(cat /tmp/enzos-qemu.pid)
rm /tmp/enzos-qemu.pid
```

## Environment Variables

- `QEMU_MONITOR_ADDR` (default: `127.0.0.1:45454`) - QEMU monitor TCP address
- `VNC_PORT` (default: `1`) - VNC display number (actual port = 5900 + VNC_PORT)
- `ISO_PATH` (default: `enzos.iso`) - Path to the EnzOS ISO file
- `QEMU_PIDFILE` (default: `/tmp/enzos-shell-scenarios.pid`) - Where to store QEMU PID

## Troubleshooting

### "QEMU_MONITOR_ADDR not set; skipping test"

The tests require QEMU to be running with the monitor enabled. Use the script or set the environment variable:

```bash
export QEMU_MONITOR_ADDR=127.0.0.1:45454
```

### "Failed to connect to QEMU monitor"

Make sure QEMU is running and the monitor is accessible:

```bash
# Test monitor connection
cd /Users/toni/Projects/enzos
go run ./cmd/main.go monitor wait -addr 127.0.0.1:45454 -timeout 5s
```

### Port already in use

If you get "address already in use" errors:

```bash
# Find and kill existing QEMU process
pkill -f qemu-system-x86_64

# Or find the specific PID
lsof -i :45454
```

## Test Structure

The new test framework uses declarative scenarios:

```go
scenarios := []tools.CommandScenario{
    {
        Name:             "Echo Hello World",
        Command:          `echo "Hello, World"`,
        Expected:         "Hello, World",
        WaitForPrompt:    true,
        CheckPromptAfter: true,
    },
}
```

Each scenario can:

- Execute shell commands (converted to keystrokes automatically)
- Use explicit keystroke sequences
- Wait for the shell prompt before executing
- Verify expected output appears
- Verify prompt returns after command execution
