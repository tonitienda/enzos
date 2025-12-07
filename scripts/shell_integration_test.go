package scripts_test

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"enzos/scripts/vga"
)

type monitorClient struct {
	addr string
	conn net.Conn
	rw   *bufio.ReadWriter
}

func newMonitorClient(t *testing.T) *monitorClient {
	t.Helper()

	addr := monitorAddr(t)
	conn, err := net.DialTimeout("tcp", addr, 3*time.Second)
	if err != nil {
		t.Fatalf("failed to connect to qemu monitor at %s: %v", addr, err)
	}

	client := &monitorClient{
		addr: addr,
		conn: conn,
		rw:   bufio.NewReadWriter(bufio.NewReader(conn), bufio.NewWriter(conn)),
	}

	client.readUntilPrompt(t)
	return client
}

func (m *monitorClient) Close() {
	_ = m.conn.Close()
}

func (m *monitorClient) run(t *testing.T, cmd string) string {
	t.Helper()

	if _, err := m.rw.WriteString(cmd + "\n"); err != nil {
		t.Fatalf("failed to send %q to monitor %s: %v", cmd, m.addr, err)
	}
	if err := m.rw.Flush(); err != nil {
		t.Fatalf("failed to flush monitor command %q: %v", cmd, err)
	}

	return m.readUntilPrompt(t)
}

func (m *monitorClient) readUntilPrompt(t *testing.T) string {
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

			// Check if we've received the (qemu) prompt
			if strings.Contains(output.String(), "(qemu)") {
				break
			}
		}

		if err != nil {
			t.Fatalf("monitor read failed: %v\nPartial output:%s", err, output.String())
		}
	}

	return output.String()
}

func monitorAddr(t *testing.T) string {
	t.Helper()

	addr := os.Getenv("QEMU_MONITOR_ADDR")
	if addr == "" {
		t.Skip("QEMU_MONITOR_ADDR not set; assuming QEMU is managed externally")
	}

	return addr
}

func runShellScenario(t *testing.T, keys []string, bootDelay time.Duration) string {
	t.Helper()
	client := newMonitorClient(t)
	defer client.Close()

	// Wait for boot
	if bootDelay > 0 {
		time.Sleep(bootDelay)
	}

	// Wait for the shell prompt to appear before sending keys
	if err := waitForPrompt(t, client, 10*time.Second); err != nil {
		t.Fatalf("shell prompt did not appear: %v", err)
	}

	for _, key := range keys {
		client.run(t, fmt.Sprintf("sendkey %s", key))
		time.Sleep(100 * time.Millisecond)
	}

	// Give the shell a moment to process the final command
	time.Sleep(200 * time.Millisecond)

	output := client.run(t, "xp /4000bx 0xb8000")
	text, err := vga.ExtractCharacters(output)
	if err != nil {
		t.Fatalf("failed to parse VGA buffer: %v\nOutput:%s", err, output)
	}

	return text
}

func waitForPrompt(t *testing.T, client *monitorClient, timeout time.Duration) error {
	t.Helper()

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

func TestShellShowsPrompt(t *testing.T) {
	text := runShellScenario(t, nil, 3*time.Second)

	if !strings.Contains(text, "$ ") && !strings.Contains(text, "$") {
		t.Fatalf("prompt not rendered in VGA output: %q", text)
	}
}

func TestShellEchoCommand(t *testing.T) {
	keys := []string{
		"e", "c", "h", "o", "spc",
		"shift-apostrophe",
		"shift-h", "e", "l", "l", "o", "comma", "spc",
		"shift-w", "o", "r", "l", "d",
		"shift-apostrophe",
		"ret",
	}

	text := runShellScenario(t, keys, 3*time.Second)

	if !strings.Contains(text, "echo \"Hello, World\"") {
		t.Fatalf("echo command input missing from VGA output: %q", text)
	}

	if !strings.Contains(text, "Hello, World") {
		t.Fatalf("echo command did not render output: %q", text)
	}
}

func TestShellShowsPromptAfterNewline(t *testing.T) {
	text := runShellScenario(t, []string{"ret"}, 3*time.Second)

	if strings.Count(text, "$") < 2 {
		t.Fatalf("expected prompt to reappear after newline, output: %q", text)
	}
}
