# Integration Test Fix Summary

## Problem Identified

The integration tests in CI were capturing screenshots before the shell had fully initialized and processed the keystroke commands. This resulted in screenshots showing only the initial boot screen without the echo command output.

### Root Cause

The test code had a **race condition**:

1. Wait 2 seconds after QEMU starts
2. Immediately send keystrokes
3. Capture VGA buffer

In CI environments (which can be slower), 2 seconds wasn't always enough for the shell to:

- Complete boot initialization
- Render the prompt
- Be ready to accept keyboard input

When keys were sent too early, they were lost — the shell hadn't started reading from the keyboard buffer yet.

## Solution Implemented

### 1. Added Prompt Detection (`waitForPrompt` function)

Instead of blindly waiting and hoping the shell is ready, the test now **actively polls** the VGA buffer until it detects the `$` prompt:

```go
func waitForPrompt(t *testing.T, client *monitorClient, timeout time.Duration) error {
    deadline := time.Now().Add(timeout)
    for time.Now().Before(deadline) {
        output := client.run(t, "xp /4000bx 0xb8000")
        text, err := vga.ExtractCharacters(output)
        if err != nil {
            return fmt.Errorf("failed to parse VGA buffer: %w", err)
        }

        // Check if the prompt is visible
        if strings.Contains(text, "$ ") || strings.Contains(text, "$") {
            t.Logf("Shell prompt detected after waiting")
            return nil
        }

        time.Sleep(500 * time.Millisecond)
    }

    return fmt.Errorf("timeout waiting for shell prompt")
}
```

**Key improvements:**

- Polls every 500ms for up to 10 seconds
- Only proceeds with keystroke sending once prompt is confirmed
- Provides clear error if prompt never appears

### 2. Increased Boot Delay

Changed from 2 seconds to 3 seconds as a base delay before even checking for the prompt. This gives the system more time to stabilize.

### 3. Added Post-Command Delay

After sending the final keystroke (e.g., the Enter key), the test now waits an additional 200ms before capturing the VGA buffer. This ensures the command output has been rendered to the screen.

### 4. Created Local Test Runner

Created `scripts/run-integration-tests-local.sh` to make it easy to reproduce and debug the tests locally:

```bash
./scripts/run-integration-tests-local.sh
```

This script:

- Starts QEMU with monitor and VNC enabled
- Runs the integration tests
- Allows you to connect with a VNC viewer to watch in real-time

## Files Changed

1. **`scripts/shell_integration_test.go`**

   - Added `waitForPrompt()` function
   - Increased boot delay from 2s to 3s
   - Added 200ms post-command delay
   - Modified `runShellScenario()` to wait for prompt before sending keys

2. **`scripts/run-integration-tests-local.sh`** (new file)

   - Helper script for local testing
   - Mimics CI environment setup
   - Enables VNC for visual debugging

3. **`scripts/README.md`** (new file)
   - Complete documentation for all scripts
   - Troubleshooting guide
   - Environment variable reference
   - Timing parameter explanations

## How to Test Locally

### Quick Test

```bash
# Build the ISO
just build-iso

# Run integration tests with local QEMU instance
./scripts/run-integration-tests-local.sh
```

### Watch Tests in Real-Time

```bash
# Terminal 1: Run the test script
./scripts/run-integration-tests-local.sh

# Terminal 2: Connect VNC viewer
vncviewer 127.0.0.1:1
```

### Manual Setup (for debugging)

```bash
# Terminal 1: Start QEMU with monitor
qemu-system-x86_64 \
  -cdrom enzos.iso \
  -serial stdio \
  -no-reboot \
  -no-shutdown \
  -monitor tcp:127.0.0.1:45454,server=on,wait=off \
  -vnc 127.0.0.1:1

# Terminal 2: Run tests
export QEMU_MONITOR_ADDR=127.0.0.1:45454
go test ./scripts -v -run TestShell
```

## Expected Behavior After Fix

✅ Tests will now wait for the shell prompt before sending keys  
✅ Keys will be processed by the shell (not lost)  
✅ VNC screenshots will capture the complete interaction  
✅ Tests should be more reliable in CI environments  
✅ Clear error messages if prompt doesn't appear within 10 seconds

## Timing Parameters

| Parameter          | Old Value | New Value | Purpose                                 |
| ------------------ | --------- | --------- | --------------------------------------- |
| Boot delay         | 2s        | 3s        | Initial wait before checking for prompt |
| Prompt wait        | N/A       | 10s       | Maximum time to wait for `$` prompt     |
| Poll interval      | N/A       | 500ms     | How often to check for prompt           |
| Key delay          | 100ms     | 100ms     | Delay between individual keystrokes     |
| Post-command delay | 0ms       | 200ms     | Wait after final keystroke for output   |

These timings are conservative to handle slower CI environments while still keeping tests reasonably fast.
