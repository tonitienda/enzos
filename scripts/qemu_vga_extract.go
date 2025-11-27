// Command qemu_vga_extract prints printable VGA text characters from a QEMU monitor dump.
//
// The dump lists bytes as two-digit hex values. The VGA text buffer uses pairs of
// bytes per cell: the character byte followed by an attribute byte. This tool
// keeps the character bytes and drops the attributes, mirroring the logic in
// qemu-smoketest.sh.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var hexBytePattern = regexp.MustCompile(`0x?([0-9a-fA-F]{2})`)

func extractCharacters(contents string) (string, error) {
	matches := hexBytePattern.FindAllStringSubmatch(contents, -1)

	var builder strings.Builder
	for index, match := range matches {
		if index%2 != 0 {
			continue // Skip attribute bytes.
		}

		byteHex := match[1]
		if byteHex == "00" {
			continue
		}

		value, err := strconv.ParseInt(byteHex, 16, 64)
		if err != nil {
			return "", fmt.Errorf("invalid hex byte %q: %w", byteHex, err)
		}
		builder.WriteRune(rune(value))
	}

	return builder.String(), nil
}

func usage() {
	fmt.Fprintf(os.Stderr, "usage: %s <dump_path>\n", filepath.Base(os.Args[0]))
}

func main() {
	if len(os.Args) != 2 {
		usage()
		os.Exit(1)
	}

	dumpPath := os.Args[1]
	contents, err := os.ReadFile(dumpPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "dump file error: %v\n", err)
		os.Exit(1)
	}

	chars, err := extractCharacters(string(contents))
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}

	fmt.Println(chars)
}
