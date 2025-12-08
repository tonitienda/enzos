package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
)

func captureVNCScreenshot(addr string, port int, wait time.Duration, outputPath, logPath string) error {
	if outputPath == "" {
		return fmt.Errorf("output path is required for VNC capture")
	}

	if _, err := exec.LookPath("vncsnapshot"); err != nil {
		return fmt.Errorf("vncsnapshot is required for VNC capture: %w", err)
	}

	if wait > 0 {
		time.Sleep(wait)
	}

	logFile, err := os.Create(logPath)
	if err != nil {
		return fmt.Errorf("create log file: %w", err)
	}
	defer logFile.Close()

	target := fmt.Sprintf("%s:%d", addr, port)
	cmd := exec.Command("vncsnapshot", "-quiet", target, outputPath)
	cmd.Stdout = logFile
	cmd.Stderr = logFile

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("vncsnapshot failed (log: %s): %w", logPath, err)
	}

	if err := os.Chmod(outputPath, 0o644); err != nil {
		return fmt.Errorf("update permissions for %s: %w", outputPath, err)
	}

	return nil
}
