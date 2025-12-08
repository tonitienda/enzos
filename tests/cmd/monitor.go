package main

import (
	"bufio"
	"bytes"
	"errors"
	"io"
	"net"
	"time"
)

const monitorPrompt = "(qemu)"

func monitorDial(addr string, timeout time.Duration) (net.Conn, error) {
	return net.DialTimeout("tcp", addr, timeout)
}

func readUntilMonitorPrompt(r *bufio.Reader, conn net.Conn, w io.Writer, deadline time.Time) (bool, error) {
	if !deadline.IsZero() {
		if err := conn.SetReadDeadline(deadline); err != nil {
			return false, err
		}
	}

	buffer := make([]byte, 0, 1024)
	tmp := make([]byte, 1)

	for {
		n, err := r.Read(tmp)
		if n > 0 {
			buffer = append(buffer, tmp[:n]...)
			if _, writeErr := w.Write(tmp[:n]); writeErr != nil {
				return false, writeErr
			}

			if bytes.Contains(buffer, []byte(monitorPrompt)) {
				return true, nil
			}
		}

		if err != nil {
			if errors.Is(err, io.EOF) {
				return false, nil
			}
			return false, err
		}
	}
}

func waitForMonitor(addr string, dialTimeout time.Duration) error {
	conn, err := monitorDial(addr, dialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	reader := bufio.NewReader(conn)
	seenPrompt, err := readUntilMonitorPrompt(reader, conn, io.Discard, time.Now().Add(dialTimeout))
	if err != nil {
		return err
	}
	if !seenPrompt {
		return errors.New("monitor prompt not detected")
	}

	return nil
}

func execMonitorCommand(addr, cmd string, dialTimeout time.Duration, w io.Writer) error {
	conn, err := monitorDial(addr, dialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	reader := bufio.NewReader(conn)
	writer := bufio.NewWriter(conn)

	if _, err := readUntilMonitorPrompt(reader, conn, w, time.Time{}); err != nil {
		return err
	}

	if _, err := writer.WriteString(cmd + "\n"); err != nil {
		return err
	}
	if err := writer.Flush(); err != nil {
		return err
	}

	_, err = readUntilMonitorPrompt(reader, conn, w, time.Time{})
	return err
}

func monitorUsage() string {
	return "monitor <wait|exec> [options]"
}
