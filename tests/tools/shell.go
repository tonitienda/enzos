package tools

import (
	"fmt"
	"strings"
	"time"
)

const (
	// VGAWordCount is the number of VGA buffer words to read
	// VGA text mode: 80 columns × 25 rows × 2 bytes (char + attr) = 4000 bytes
	VGAWordCount = 4000
	// ShellPrompt is the expected shell prompt string
	ShellPrompt = "$ "
)

// ShellRunner provides utilities for running shell commands via QEMU monitor.
type ShellRunner struct {
	monitor *Monitor
}

// NewShellRunner creates a new ShellRunner using the provided monitor.
func NewShellRunner(monitor *Monitor) *ShellRunner {
	return &ShellRunner{monitor: monitor}
}

// WaitForPrompt waits for the shell prompt to appear in the VGA buffer.
func (s *ShellRunner) WaitForPrompt(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		output, err := s.monitor.ReadVGABuffer(VGAWordCount)
		if err != nil {
			return fmt.Errorf("failed to read VGA buffer: %w", err)
		}

		text, err := ExtractVGAText(output)
		if err != nil {
			return fmt.Errorf("failed to parse VGA buffer: %w", err)
		}

		if strings.Contains(text, ShellPrompt) || strings.Contains(text, "$") {
			return nil
		}

		time.Sleep(500 * time.Millisecond)
	}

	return fmt.Errorf("timeout waiting for shell prompt")
}

// SendKeys sends a sequence of keystrokes with delays between them.
func (s *ShellRunner) SendKeys(keys []string, delayBetweenKeys time.Duration) error {
	for _, key := range keys {
		if err := s.monitor.SendKey(key); err != nil {
			return fmt.Errorf("failed to send key %q: %w", key, err)
		}
		if delayBetweenKeys > 0 {
			time.Sleep(delayBetweenKeys)
		}
	}
	return nil
}

// ReadVGAText reads and parses the current VGA buffer text.
func (s *ShellRunner) ReadVGAText() (string, error) {
	output, err := s.monitor.ReadVGABuffer(VGAWordCount)
	if err != nil {
		return "", fmt.Errorf("failed to read VGA buffer: %w", err)
	}

	text, err := ExtractVGAText(output)
	if err != nil {
		return "", fmt.Errorf("failed to parse VGA buffer: %w", err)
	}

	return text, nil
}

// CommandScenario represents a shell command test scenario.
type CommandScenario struct {
	Name              string        // Test scenario name
	Command           string        // Command to execute (empty for just checking boot)
	Keys              []string      // Alternative: explicit keystroke sequence
	Expected          string        // Expected text in output
	BootDelay         time.Duration // Initial delay before executing command
	PostDelay         time.Duration // Delay after command before reading output
	KeystrokeDelay    time.Duration // Delay between keystrokes (default 100ms)
	PostScenarioDelay time.Duration // Delay after scenario completes (for demo mode)
	WaitForPrompt     bool          // Whether to wait for prompt before executing
	CheckPromptAfter  bool          // Whether to verify prompt appears after expected text
	Screenshot        string        // Optional: screenshot filename (e.g., "boot.ppm")
}

// RunScenario executes a command scenario and returns the VGA text output.
func (s *ShellRunner) RunScenario(scenario CommandScenario) (string, error) {
	// Apply boot delay if specified
	if scenario.BootDelay > 0 {
		time.Sleep(scenario.BootDelay)
	}

	// Wait for shell prompt if requested
	if scenario.WaitForPrompt {
		if err := s.WaitForPrompt(10 * time.Second); err != nil {
			return "", fmt.Errorf("shell prompt did not appear: %w", err)
		}
	}

	// Determine keys to send
	var keys []string
	if len(scenario.Keys) > 0 {
		keys = scenario.Keys
	} else if scenario.Command != "" {
		keys = CommandToKeys(scenario.Command)
	}

	// Send keystrokes
	if len(keys) > 0 {
		keystrokeDelay := scenario.KeystrokeDelay
		if keystrokeDelay == 0 {
			keystrokeDelay = 100 * time.Millisecond // Default
		}
		if err := s.SendKeys(keys, keystrokeDelay); err != nil {
			return "", err
		}
	}

	// Post-command delay
	if scenario.PostDelay > 0 {
		time.Sleep(scenario.PostDelay)
	} else if len(keys) > 0 {
		time.Sleep(200 * time.Millisecond) // Default post-command delay
	}

	// Read VGA output
	text, err := s.ReadVGAText()
	if err != nil {
		return "", err
	}

	// Verify expected text if specified
	if scenario.Expected != "" && !strings.Contains(text, scenario.Expected) {
		return text, fmt.Errorf("expected text %q not found in output", scenario.Expected)
	}

	// Verify prompt appears after expected text if requested
	if scenario.CheckPromptAfter && scenario.Expected != "" {
		// Wait a bit more for prompt to appear
		time.Sleep(500 * time.Millisecond)
		text, err = s.ReadVGAText()
		if err != nil {
			return text, err
		}

		if !strings.Contains(text, ShellPrompt) && !strings.Contains(text, "$") {
			return text, fmt.Errorf("prompt did not appear after expected output")
		}
	}

	// Take screenshot if requested
	if scenario.Screenshot != "" {
		if err := s.monitor.Screenshot(scenario.Screenshot); err != nil {
			return text, fmt.Errorf("failed to capture screenshot: %w", err)
		}
	}

	// Post-scenario delay (for demo mode)
	if scenario.PostScenarioDelay > 0 {
		time.Sleep(scenario.PostScenarioDelay)
	}

	return text, nil
}

// CommandToKeys converts a shell command string to a sequence of QEMU keystrokes.
func CommandToKeys(command string) []string {
	var keys []string

	for _, char := range command {
		switch char {
		case ' ':
			keys = append(keys, "spc")
		case '\n':
			keys = append(keys, "ret")
		case '"':
			keys = append(keys, "shift-apostrophe")
		case '\'':
			keys = append(keys, "apostrophe")
		case ',':
			keys = append(keys, "comma")
		case '.':
			keys = append(keys, "dot")
		case '-':
			keys = append(keys, "minus")
		case '=':
			keys = append(keys, "equal")
		case '/':
			keys = append(keys, "slash")
		case '\\':
			keys = append(keys, "backslash")
		case ';':
			keys = append(keys, "semicolon")
		case '[':
			keys = append(keys, "bracket_left")
		case ']':
			keys = append(keys, "bracket_right")
		case '(':
			keys = append(keys, "shift-9")
		case ')':
			keys = append(keys, "shift-0")
		default:
			if char >= 'A' && char <= 'Z' {
				keys = append(keys, fmt.Sprintf("shift-%c", char+'a'-'A'))
			} else if char >= 'a' && char <= 'z' || char >= '0' && char <= '9' {
				keys = append(keys, string(char))
			}
		}
	}

	// Always append return key to execute the command
	keys = append(keys, "ret")

	return keys
}
