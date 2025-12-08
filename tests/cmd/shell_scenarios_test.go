package main

import (
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/tonitienda/enzos/tests/tools"
)

func getTestEnv(t *testing.T) (monitorAddr string, vncPort int) {
	t.Helper()

	monitorAddr = os.Getenv("QEMU_MONITOR_ADDR")
	if monitorAddr == "" {
		t.Skip("QEMU_MONITOR_ADDR not set; skipping test")
	}

	vncPort = 1
	if envPort := os.Getenv("VNC_PORT"); envPort != "" {
		if parsed, err := strconv.Atoi(envPort); err == nil {
			vncPort = parsed
		}
	}

	return monitorAddr, vncPort
}

func TestShellScenarios(t *testing.T) {
	monitorAddr, _ := getTestEnv(t)

	// Create monitor connection
	monitor, err := tools.NewMonitor(monitorAddr, 3*time.Second)
	if err != nil {
		t.Fatalf("Failed to connect to QEMU monitor: %v", err)
	}
	defer monitor.Close()

	// Create shell runner
	shell := tools.NewShellRunner(monitor)

	// Get screenshot directory (current working directory or project root)
	screenshotDir := os.Getenv("SCREENSHOT_DIR")
	if screenshotDir == "" {
		if wd, err := os.Getwd(); err == nil {
			screenshotDir = wd
		} else {
			screenshotDir = "/tmp"
		}
	}

	// Check if demo mode is enabled (slower execution for visibility)
	demoMode := os.Getenv("DEMO_MODE") == "1"
	var keystrokeDelay time.Duration
	var scenarioDelay time.Duration

	if demoMode {
		keystrokeDelay = 300 * time.Millisecond // Slow typing for visibility
		scenarioDelay = 5 * time.Second         // Pause between scenarios (5s to see results)
		t.Logf("Demo mode enabled: slow keystrokes and 5-second pauses between scenarios")
	}

	// Define test scenarios
	scenarios := []tools.CommandScenario{
		{
			Name:              "System Boot",
			Command:           "",              // No command, just check boot
			Expected:          "$",             // Look for shell prompt
			BootDelay:         6 * time.Second, // Wait for splash + boot message + shell
			WaitForPrompt:     false,
			Screenshot:        screenshotDir + "/screen-boot.ppm",
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:              "Shell Prompt Appears",
			Command:           "", // No command
			Expected:          "$",
			BootDelay:         0, // Already booted
			WaitForPrompt:     true,
			CheckPromptAfter:  false,
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:              "Echo Hello World",
			Command:           `echo "Hello, World"`,
			Expected:          "Hello, World",
			WaitForPrompt:     true,
			CheckPromptAfter:  true,
			KeystrokeDelay:    keystrokeDelay,
			Screenshot:        screenshotDir + "/screen-echo.ppm",
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:              "Prompt After Newline",
			Keys:              []string{"ret"}, // Just press enter
			Expected:          "$",
			WaitForPrompt:     true,
			CheckPromptAfter:  true,
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:              "Final Screen State",
			Command:           "",
			Expected:          "$",
			Screenshot:        screenshotDir + "/screen-final.ppm",
			PostScenarioDelay: scenarioDelay,
		},
	}

	// Run scenarios sequentially
	for _, scenario := range scenarios {
		t.Run(scenario.Name, func(t *testing.T) {
			text, err := shell.RunScenario(scenario)
			if err != nil {
				t.Fatalf("Scenario failed: %v\nVGA output:\n%s", err, text)
			}

			// Log VGA output for debugging
			if scenario.Name == "Final Screen State" {
				t.Logf("=== FINAL SCREEN STATE ===\n%s\n=== END SCREEN STATE ===", text)
			} else {
				t.Logf("Scenario %q passed. VGA output:\n%s", scenario.Name, text)
			}
		})
	}
}
