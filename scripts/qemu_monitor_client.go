package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"
)

func readUntilPrompt(r *bufio.Reader, conn net.Conn, w io.Writer, deadline time.Time) (bool, error) {
	if !deadline.IsZero() {
		if err := conn.SetReadDeadline(deadline); err != nil {
			return false, err
		}
	}

	for {
		line, err := r.ReadString('\n')
		if len(line) > 0 {
			if _, writeErr := io.WriteString(w, line); writeErr != nil {
				return false, writeErr
			}
			if strings.Contains(line, "(qemu)") {
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

func dial(addr string, timeout time.Duration) (net.Conn, error) {
	return net.DialTimeout("tcp", addr, timeout)
}

func runWait(addr string, dialTimeout time.Duration) error {
	conn, err := dial(addr, dialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	reader := bufio.NewReader(conn)
	promptSeen, err := readUntilPrompt(reader, conn, io.Discard, time.Now().Add(dialTimeout))
	if err != nil {
		return err
	}
	if !promptSeen {
		return errors.New("monitor prompt not detected")
	}
	return nil
}

func runExec(addr, cmd string, dialTimeout time.Duration) error {
	conn, err := dial(addr, dialTimeout)
	if err != nil {
		return err
	}
	defer conn.Close()

	reader := bufio.NewReader(conn)
	writer := bufio.NewWriter(conn)

	if _, err := readUntilPrompt(reader, conn, os.Stdout, time.Time{}); err != nil {
		return err
	}

	if _, err := writer.WriteString(cmd + "\n"); err != nil {
		return err
	}
	if err := writer.Flush(); err != nil {
		return err
	}

	_, err = readUntilPrompt(reader, conn, os.Stdout, time.Time{})
	return err
}

func main() {
	var (
		mode        string
		addr        string
		cmd         string
		dialTimeout time.Duration
	)

	flag.StringVar(&mode, "mode", "wait", "Mode to run: wait or exec")
	flag.StringVar(&addr, "addr", "127.0.0.1:45454", "QEMU monitor address")
	flag.StringVar(&cmd, "cmd", "", "Command to send in exec mode")
	flag.DurationVar(&dialTimeout, "timeout", 5*time.Second, "Dial timeout for monitor connection")
	flag.Parse()

	var err error
	switch mode {
	case "wait":
		err = runWait(addr, dialTimeout)
	case "exec":
		if cmd == "" {
			err = errors.New("cmd is required in exec mode")
		} else {
			err = runExec(addr, cmd, dialTimeout)
		}
	default:
		err = fmt.Errorf("unknown mode %q", mode)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
