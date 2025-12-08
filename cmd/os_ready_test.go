package main

import (
	"strings"
	"testing"
)

const osReadyMessage = "EnzOS booted successfully."

func TestOSIsReady(t *testing.T) {
	env := newQEMUTestEnv(t)
	env.waitForMonitor(t)
	env.captureAfterTest(t, "qemu-screen-os-is-ready.ppm", "qemu-screen-smoke.ppm")

	raw, text := env.captureVGABuffer(t)
	env.writeVGADumps(t, raw, text)

	if !strings.Contains(text, osReadyMessage) {
		t.Fatalf("boot message not found in VGA text: %q", text)
	}
}
