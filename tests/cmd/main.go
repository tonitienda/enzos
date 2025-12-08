package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	var err error
	switch os.Args[1] {
	case "monitor":
		err = runMonitor(os.Args[2:])
	case "vga":
		err = runVGA(os.Args[2:])
	case "vnc":
		err = runVNC(os.Args[2:])
	default:
		printUsage()
		os.Exit(1)
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Fprintf(os.Stderr, "usage: go run cmd/main.go <monitor|vga|vnc>\n")
}

func runMonitor(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("monitor command required. %s", monitorUsage())
	}

	subcommand := args[0]
	fs := flag.NewFlagSet("monitor"+subcommand, flag.ContinueOnError)
	addr := fs.String("addr", "127.0.0.1:45454", "QEMU monitor address")
	cmd := fs.String("cmd", "", "Command to execute in exec mode")
	timeout := fs.Duration("timeout", 5*time.Second, "Dial timeout")
	fs.SetOutput(io.Discard)

	if err := fs.Parse(args[1:]); err != nil {
		return err
	}

	switch subcommand {
	case "wait":
		return waitForMonitor(*addr, *timeout)
	case "exec":
		if *cmd == "" {
			return errors.New("-cmd is required in exec mode")
		}
		return execMonitorCommand(*addr, *cmd, *timeout, os.Stdout)
	default:
		return fmt.Errorf("unknown monitor subcommand %q", subcommand)
	}
}

func runVGA(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("vga subcommand required. %s", vgaUsage(os.Args[0]))
	}

	switch args[0] {
	case "extract":
		if len(args) < 2 {
			return fmt.Errorf("vga extract requires a dump path. %s", vgaUsage(os.Args[0]))
		}

		contents, err := os.ReadFile(args[1])
		if err != nil {
			return fmt.Errorf("read VGA dump: %w", err)
		}

		text, err := ExtractCharacters(string(contents))
		if err != nil {
			return err
		}

		fmt.Println(text)
		return nil
	default:
		return fmt.Errorf("unknown vga subcommand %q", args[0])
	}
}

func runVNC(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("vnc subcommand required. usage: go run cmd/main.go vnc capture [options]")
	}

	subcommand := args[0]
	fs := flag.NewFlagSet("vnc"+subcommand, flag.ContinueOnError)
	addr := fs.String("addr", "127.0.0.1", "VNC server address")
	port := fs.Int("port", 1, "VNC display port")
	wait := fs.Duration("wait", 2*time.Second, "Delay before taking screenshot")
	outputPath := fs.String("output", "", "Path to write VNC screenshot")
	logPath := fs.String("log", "qemu-vnc-client.log", "Path to write VNC client log")
	fs.SetOutput(io.Discard)

	if err := fs.Parse(args[1:]); err != nil {
		return err
	}

	switch subcommand {
	case "capture":
		return captureVNCScreenshot(*addr, *port, *wait, *outputPath, *logPath)
	default:
		return fmt.Errorf("unknown vnc subcommand %q", subcommand)
	}
}
