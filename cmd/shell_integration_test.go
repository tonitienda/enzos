package main

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"testing"
	"time"
)

type monitorTestClient struct {
	addr string
	conn net.Conn
	rw   *bufio.ReadWriter
}

func (m *monitorTestClient) Close() {
	_ = m.conn.Close()
}

func (m *monitorTestClient) run(t *testing.T, cmd string) string {
	t.Helper()

	if _, err := m.rw.WriteString(cmd + "\n"); err != nil {
		t.Fatalf("failed to send %q to monitor %s: %v", cmd, m.addr, err)
	}
	if err := m.rw.Flush(); err != nil {
		t.Fatalf("failed to flush monitor command %q: %v", cmd, err)
	}

	return m.readUntilPrompt(t)
}

func (m *monitorTestClient) readUntilPrompt(t *testing.T) string {
	t.Helper()

	if err := m.conn.SetReadDeadline(time.Now().Add(30 * time.Second)); err != nil {
		t.Fatalf("failed to set monitor read deadline: %v", err)
	}

	var output strings.Builder
	tmp := make([]byte, 1)

	for {
		n, err := m.rw.Read(tmp)
		if n > 0 {
			output.Write(tmp[:n])

			if strings.Contains(output.String(), monitorPrompt) {
				break
			}
		}

		if err != nil {
			t.Fatalf("monitor read failed: %v\nPartial output:%s", err, output.String())
		}
	}

	return output.String()
}

func runShellScenario(t *testing.T, env qemuTestEnv, keys []string, bootDelay time.Duration) string {
	t.Helper()
	client := env.newMonitorClient(t)
	defer client.Close()

	if bootDelay > 0 {
		time.Sleep(bootDelay)
	}

	if err := waitForShellPrompt(t, client, 10*time.Second); err != nil {
		t.Fatalf("shell prompt did not appear: %v", err)
	}

	for _, key := range keys {
		client.run(t, fmt.Sprintf("sendkey %s", key))
		time.Sleep(100 * time.Millisecond)
	}

	time.Sleep(200 * time.Millisecond)

	output := client.run(t, "xp /4000bx 0xb8000")
	text, err := ExtractCharacters(output)
	if err != nil {
		t.Fatalf("failed to parse VGA buffer: %v\nOutput:%s", err, output)
	}

	return text
}

func waitForShellPrompt(t *testing.T, client *monitorTestClient, timeout time.Duration) error {
	t.Helper()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		output := client.run(t, "xp /4000bx 0xb8000")
		text, err := ExtractCharacters(output)
		if err != nil {
			return fmt.Errorf("failed to parse VGA buffer: %w", err)
		}

		if strings.Contains(text, "$ ") || strings.Contains(text, "$") {
			t.Logf("Shell prompt detected after waiting")
			return nil
		}

		time.Sleep(500 * time.Millisecond)
	}

	return fmt.Errorf("timeout waiting for shell prompt")
}

func TestShellScenarios(t *testing.T) {
	env := newQEMUTestEnv(t)
	env.waitForMonitor(t)

	t.Run("ShowsPrompt", func(t *testing.T) {
		env.captureAfterTest(t, "qemu-screen-integration.ppm")
		text := runShellScenario(t, env, nil, 3*time.Second)

		if !strings.Contains(text, "$ ") && !strings.Contains(text, "$") {
			t.Fatalf("prompt not rendered in VGA output: %q", text)
		}
	})

	t.Run("EchoCommand", func(t *testing.T) {
		env.captureAfterTest(t, "qemu-screen-integration-terminal.ppm")

		keys := []string{
			"e", "c", "h", "o", "spc",
			"shift-apostrophe",
			"shift-h", "e", "l", "l", "o", "comma", "spc",
			"shift-w", "o", "r", "l", "d",
			"shift-apostrophe",
			"ret",
		}

		text := runShellScenario(t, env, keys, 3*time.Second)

		if !strings.Contains(text, "echo \"Hello, World\"") {
			t.Fatalf("echo command input missing from VGA output: %q", text)
		}

		if !strings.Contains(text, "Hello, World") {
			t.Fatalf("echo command did not render output: %q", text)
		}
	})

	t.Run("ShowsPromptAfterNewline", func(t *testing.T) {
		env.captureAfterTest(t)

		text := runShellScenario(t, env, []string{"ret"}, 3*time.Second)

		if strings.Count(text, "$") < 2 {
			t.Fatalf("expected prompt to reappear after newline, output: %q", text)
		}
	})
}
