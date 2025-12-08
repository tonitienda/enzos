package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

type qemuTestEnv struct {
	monitorAddr string
	vncAddr     string
	vncPort     int
	vncWait     time.Duration
}

func newQEMUTestEnv(t *testing.T) qemuTestEnv {
	t.Helper()

	monitor := os.Getenv("QEMU_MONITOR_ADDR")
	if monitor == "" {
		t.Skip("QEMU_MONITOR_ADDR not set; assuming QEMU is managed externally")
	}

	vncAddr := os.Getenv("VNC_CONNECT_ADDR")
	if vncAddr == "" {
		vncAddr = "127.0.0.1"
	}

	port := 1
	if envPort := os.Getenv("VNC_PORT"); envPort != "" {
		if parsed, err := strconv.Atoi(envPort); err == nil {
			port = parsed
		}
	}

	wait := 2 * time.Second
	if envWait := os.Getenv("VNC_WAIT_SECONDS"); envWait != "" {
		if parsed, err := strconv.Atoi(envWait); err == nil {
			wait = time.Duration(parsed) * time.Second
		} else if dur, err := time.ParseDuration(envWait); err == nil {
			wait = dur
		}
	}

	return qemuTestEnv{
		monitorAddr: monitor,
		vncAddr:     vncAddr,
		vncPort:     port,
		vncWait:     wait,
	}
}

func (env qemuTestEnv) newMonitorClient(t *testing.T) *monitorTestClient {
	t.Helper()

	conn, err := net.DialTimeout("tcp", env.monitorAddr, 3*time.Second)
	if err != nil {
		t.Fatalf("failed to connect to qemu monitor at %s: %v", env.monitorAddr, err)
	}

	client := &monitorTestClient{
		addr: env.monitorAddr,
		conn: conn,
		rw:   bufio.NewReadWriter(bufio.NewReader(conn), bufio.NewWriter(conn)),
	}

	client.readUntilPrompt(t)
	return client
}

func (env qemuTestEnv) waitForMonitor(t *testing.T) {
	t.Helper()

	if err := waitForMonitor(env.monitorAddr, 15*time.Second); err != nil {
		t.Fatalf("monitor not ready at %s: %v", env.monitorAddr, err)
	}
}

func (env qemuTestEnv) captureVGABuffer(t *testing.T) (string, string) {
	t.Helper()

	client := env.newMonitorClient(t)
	defer client.Close()

	output := client.run(t, fmt.Sprintf("xp /%dbx 0xb8000", vgaWordCount))
	text, err := ExtractCharacters(output)
	if err != nil {
		t.Fatalf("failed to parse VGA buffer: %v\nOutput:%s", err, output)
	}

	return output, text
}

func (env qemuTestEnv) writeVGADumps(t *testing.T, raw, parsed string) {
	t.Helper()

	if err := os.WriteFile("qemu-vga-dump.raw.txt", []byte(raw), 0o644); err != nil {
		t.Fatalf("write raw VGA dump: %v", err)
	}

	if err := os.WriteFile("qemu-vga-dump.txt", []byte(parsed+"\n"), 0o644); err != nil {
		t.Fatalf("write parsed VGA dump: %v", err)
	}
}

func sanitizeTestName(name string) string {
	lowered := strings.ToLower(name)
	replacer := strings.NewReplacer("/", "-", " ", "-", "_", "-", ".", "-", ":", "-", string(filepath.Separator), "-")
	cleaned := replacer.Replace(lowered)
	cleaned = strings.Trim(cleaned, "-")
	if cleaned == "" {
		return "test"
	}

	return cleaned
}

func (env qemuTestEnv) captureScreenshot(t *testing.T, testName string, aliases ...string) {
	t.Helper()

	base := sanitizeTestName(testName)
	imagePath := fmt.Sprintf("qemu-screen-%s.ppm", base)
	logPath := fmt.Sprintf("qemu-vnc-client-%s.log", base)

	if err := captureVNCScreenshot(env.vncAddr, env.vncPort, env.vncWait, imagePath, logPath); err != nil {
		t.Logf("unable to capture VNC screenshot for %s: %v", testName, err)
		return
	}

	for _, alias := range aliases {
		if err := copyFile(imagePath, alias); err != nil {
			t.Logf("copy screenshot %s -> %s failed: %v", imagePath, alias, err)
		}

		aliasLog := aliasLogPath(alias)
		if err := copyFile(logPath, aliasLog); err != nil {
			t.Logf("copy VNC log %s -> %s failed: %v", logPath, aliasLog, err)
		}
	}
}

func (env qemuTestEnv) captureAfterTest(t *testing.T, aliases ...string) {
	t.Helper()

	t.Cleanup(func() {
		env.captureScreenshot(t, t.Name(), aliases...)
	})
}

func aliasLogPath(alias string) string {
	base := strings.TrimSuffix(filepath.Base(alias), filepath.Ext(alias))
	base = strings.TrimPrefix(base, "qemu-screen-")
	return fmt.Sprintf("qemu-vnc-client-%s.log", base)
}

func copyFile(src, dst string) error {
	input, err := os.Open(src)
	if err != nil {
		return err
	}
	defer input.Close()

	output, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer output.Close()

	if _, err := io.Copy(output, input); err != nil {
		return err
	}

	return output.Close()
}
