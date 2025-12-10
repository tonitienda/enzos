package main

import (
	"os"
	"path/filepath"
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
		keystrokeDelay = 150 * time.Millisecond // Moderate typing speed (visible but not too slow)
		scenarioDelay = 2 * time.Second         // Brief pause between scenarios
		t.Logf("Demo mode enabled: moderate typing speed with 2-second pauses between scenarios")
	}

	// Define test scenarios
	scenarios := []tools.CommandScenario{
		{
			Name:              "OS Ready",
			Command:           "",
			Expected:          "$",
			BootDelay:         6 * time.Second, // Wait for splash + boot message + shell
			WaitForPrompt:     true,
			Screenshot:        filepath.Join(screenshotDir, "qemu-screen-smoke.ppm"),
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:              "Echo Hello World",
			Command:           `echo "Hello, World"`,
			Expected:          "Hello, World",
			Unexpected:        []string{"\"Hello, World\""},
			WaitForPrompt:     true,
			CheckPromptAfter:  true,
			KeystrokeDelay:    keystrokeDelay,
			Screenshot:        filepath.Join(screenshotDir, "qemu-screen-integration.ppm"),
			PostScenarioDelay: scenarioDelay,
		},
		{
			Name:             "Filesystem PWD",
			Command:          "pwd",
			Expected:         "/",
			WaitForPrompt:    true,
			CheckPromptAfter: true,
		},
		{
			Name:             "Touch And List",
			Command:          "touch notes\nls",
			Expected:         "notes",
			WaitForPrompt:    true,
			CheckPromptAfter: true,
		},
		{
			Name:             "Write And Cat",
			Command:          "echo hello world > notes\ncat notes",
			Expected:         "hello world",
			WaitForPrompt:    true,
			CheckPromptAfter: true,
		},
		{
			Name:             "Change Directory",
			Command:          "cd /\nmkdir home\ncd home\npwd",
			Expected:         "/home",
			WaitForPrompt:    true,
			CheckPromptAfter: true,
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
			t.Logf("Scenario %q passed. VGA output:\n%s", scenario.Name, text)
		})
	}

	if err := monitor.Screenshot(filepath.Join(screenshotDir, "qemu-screen-integration-terminal.ppm")); err != nil {
		t.Fatalf("Failed to capture terminal screenshot: %v", err)
	}
}
