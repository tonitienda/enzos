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
	for {
		line, err := m.rw.ReadString('\n')
		if err != nil {
			t.Fatalf("monitor read failed: %v\nPartial output:%s", err, output.String())
		}
		output.WriteString(line)

		if strings.Contains(line, "(qemu)") {
			break
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

	if bootDelay > 0 {
		time.Sleep(bootDelay)
	}

	for _, key := range keys {
		client.run(t, fmt.Sprintf("sendkey %s", key))
		time.Sleep(100 * time.Millisecond)
	}

	output := client.run(t, "xp /4000bx 0xb8000")
	text, err := vga.ExtractCharacters(output)
	if err != nil {
		t.Fatalf("failed to parse VGA buffer: %v\nOutput:%s", err, output)
	}

	return text
}

func TestShellShowsPrompt(t *testing.T) {
	text := runShellScenario(t, nil, 2*time.Second)

	if !strings.Contains(text, "$ ") && !strings.Contains(text, "$") {
		t.Fatalf("prompt not rendered in VGA output: %q", text)
	}
}

func TestShellEchoCommand(t *testing.T) {
	keys := []string{
		"e", "c", "h", "o", "spc",
		"shift-apostrophe",
		"h", "e", "l", "l", "o", "comma", "spc",
		"shift-w", "o", "r", "l", "d",
		"shift-apostrophe",
		"ret",
	}

	text := runShellScenario(t, keys, 2*time.Second)

	if !strings.Contains(text, "echo \"Hello, World\"") {
		t.Fatalf("echo command input missing from VGA output: %q", text)
	}

	if !strings.Contains(text, "Hello, World") {
		t.Fatalf("echo command did not render output: %q", text)
	}
}

func TestShellShowsPromptAfterNewline(t *testing.T) {
	text := runShellScenario(t, []string{"ret"}, 2*time.Second)

	if strings.Count(text, "$") < 2 {
		t.Fatalf("expected prompt to reappear after newline, output: %q", text)
	}
}
