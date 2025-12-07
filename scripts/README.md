# EnzOS Scripts

This directory contains scripts for building, testing, and running EnzOS.

## Build Scripts

- **`build-iso.sh`** — Builds the bootable ISO image from kernel ELF
- **`build-elf.sh`** — Compiles the kernel source to an ELF binary

## Test Scripts

### Smoke Tests

- **`qemu-smoketest.sh`** — Basic boot test that checks for the boot message in VGA memory using the Go helper CLI

**Usage:**

```bash
./scripts/qemu-smoketest.sh enzos.iso
```

### Integration Tests

- **Go-based tooling (`go run ./cmd/main.go …`)** — Sends monitor commands, parses VGA output, and captures VNC screenshots
- **`run-integration-tests-local.sh`** — Helper script to run integration tests locally with a visible QEMU instance

**Running integration tests locally:**

1. Build the ISO first:

   ```bash
   just build-iso
   ```

2. Run the integration tests:

   ```bash
   ./scripts/run-integration-tests-local.sh
   ```

3. Optional: Connect with a VNC viewer to watch the tests in real-time:
   ```bash
   vncviewer 127.0.0.1:1
   ```

The script will:

- Start QEMU with monitor and VNC enabled
- Wait for QEMU to be ready
- Run the Go integration tests
- Shut down QEMU when complete

**Manual test setup:**

If you want more control, you can start QEMU manually and run tests separately:

```bash
# Terminal 1: Start QEMU with monitor
qemu-system-x86_64 \
  -cdrom enzos.iso \
  -serial stdio \
  -no-reboot \
  -no-shutdown \
  -monitor tcp:127.0.0.1:45454,server=on,wait=off \
  -vnc 127.0.0.1:1

# Terminal 2: Run the tests
export QEMU_MONITOR_ADDR=127.0.0.1:45454
go test ./cmd -v -run TestShell
```

## Helper Tools

### Unified Go CLI

A single Go entry point powers monitor commands, VGA parsing, and VNC screenshot capture:

```bash
# Wait for the QEMU monitor to come up
go run ./cmd/main.go monitor wait --addr 127.0.0.1:45454 --timeout 5s

# Execute a monitor command
go run ./cmd/main.go monitor exec --addr 127.0.0.1:45454 --cmd "xp /4000bx 0xb8000"

# Extract readable text from a VGA dump
go run ./cmd/main.go vga extract qemu-vga-dump.raw.txt

# Capture a VNC screenshot
go run ./cmd/main.go vnc capture --addr 127.0.0.1 --port 1 --wait 2s --output screen.ppm --log vnc.log
```

## CI Integration

The GitHub Actions workflow uses these scripts to:

1. Build the ISO
2. Start QEMU with monitor and VNC
3. Run smoke tests to verify boot
4. Run integration tests that interact with the shell
5. Capture VNC screenshots for visual verification

## Troubleshooting Integration Tests

### Issue: Tests fail in CI but work locally

**Cause:** Timing differences between local and CI environments. CI VMs may be slower to boot.

**Solution:** The integration tests now include:

- Increased boot delay (3 seconds instead of 2)
- Active polling for the shell prompt before sending keys
- Extra delay after command execution to ensure output is rendered

### Issue: Keys are sent but don't appear in the shell

**Cause:** The shell wasn't ready to accept input when keys were sent.

**Solution:** The `waitForPrompt()` function now polls the VGA buffer until the `$` prompt appears before sending any keys.

### Issue: Can't see what's happening in CI

**Cause:** VNC screenshots are captured at specific moments.

**Solution:**

- Review the uploaded PNG screenshots in CI artifacts
- Run tests locally with `./scripts/run-integration-tests-local.sh` and connect via VNC to watch in real-time
- Check the VGA text dumps (`qemu-vga-dump.txt`) in CI artifacts

## Environment Variables

Integration tests and scripts respect these environment variables:

- `QEMU_MONITOR_ADDR` — Monitor TCP address (default: `127.0.0.1:45454`)
- `QEMU_PIDFILE` — Path to QEMU process ID file
- `VNC_PORT` — VNC display number (default: `1`, maps to TCP port 5901)
- `VNC_BIND_ADDR` — VNC bind address (default: `127.0.0.1`)
- `VNC_CONNECT_ADDR` — VNC client connect address (default: `127.0.0.1`)
- `QEMU_KEEP_ALIVE` — If `true`, don't shut down QEMU after tests (default: `false`)

## Key Timing Parameters

The integration tests use these timing parameters to ensure reliable operation:

- **Boot delay:** 3 seconds — Initial wait before checking for prompt
- **Prompt polling:** 10 seconds — Maximum time to wait for `$` prompt to appear
- **Poll interval:** 500ms — How often to check VGA buffer for prompt
- **Key delay:** 100ms — Delay between sending individual keystrokes
- **Post-command delay:** 200ms — Extra time after final keystroke for output to render

These values are tuned for CI environments where virtualization overhead can cause slower boot times.
