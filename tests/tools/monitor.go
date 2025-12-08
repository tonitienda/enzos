package tools

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"time"
)

const monitorPrompt = "(qemu)"

// Monitor provides a client interface to the QEMU monitor.
type Monitor struct {
	addr string
	conn net.Conn
	rw   *bufio.ReadWriter
}

// NewMonitor creates a new Monitor connection to the specified address.
func NewMonitor(addr string, timeout time.Duration) (*Monitor, error) {
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to qemu monitor at %s: %w", addr, err)
	}

	m := &Monitor{
		addr: addr,
		conn: conn,
		rw:   bufio.NewReadWriter(bufio.NewReader(conn), bufio.NewWriter(conn)),
	}

	// Read initial prompt
	if _, err := m.readUntilPrompt(); err != nil {
		m.Close()
		return nil, fmt.Errorf("failed to read initial monitor prompt: %w", err)
	}

	return m, nil
}

// Close closes the monitor connection.
func (m *Monitor) Close() error {
	if m.conn != nil {
		return m.conn.Close()
	}
	return nil
}

// Run executes a command on the QEMU monitor and returns the output.
func (m *Monitor) Run(cmd string) (string, error) {
	if _, err := m.rw.WriteString(cmd + "\n"); err != nil {
		return "", fmt.Errorf("failed to send %q to monitor %s: %w", cmd, m.addr, err)
	}
	if err := m.rw.Flush(); err != nil {
		return "", fmt.Errorf("failed to flush monitor command %q: %w", cmd, err)
	}

	return m.readUntilPrompt()
}

func (m *Monitor) readUntilPrompt() (string, error) {
	if err := m.conn.SetReadDeadline(time.Now().Add(30 * time.Second)); err != nil {
		return "", fmt.Errorf("failed to set monitor read deadline: %w", err)
	}

	var output strings.Builder
	tmp := make([]byte, 1)

	for {
		n, err := m.rw.Read(tmp)
		if n > 0 {
			output.Write(tmp[:n])

			if strings.Contains(output.String(), monitorPrompt) {
				return output.String(), nil
			}
		}

		if err != nil {
			return "", fmt.Errorf("monitor read failed: %w\nPartial output: %s", err, output.String())
		}
	}
}

// SendKey sends a keystroke to the QEMU instance.
func (m *Monitor) SendKey(key string) error {
	_, err := m.Run(fmt.Sprintf("sendkey %s", key))
	return err
}

// ReadVGABuffer reads the VGA text buffer from memory.
func (m *Monitor) ReadVGABuffer(wordCount int) (string, error) {
	return m.Run(fmt.Sprintf("xp /%dbx 0xb8000", wordCount))
}

// Screenshot captures the current screen to a PPM file using QEMU's screendump command.
func (m *Monitor) Screenshot(filename string) error {
	_, err := m.Run(fmt.Sprintf("screendump %s", filename))
	return err
}
