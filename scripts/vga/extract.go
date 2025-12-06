package vga

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const (
	vgaColumns = 80
)

var (
	hexBytePattern   = regexp.MustCompile(`\b0x?([0-9a-fA-F]{2})\b`)
	addressLineStart = regexp.MustCompile(`^[0-9a-fA-F]+:`)
)

func extractDumpRegion(contents string) string {
	lines := strings.Split(contents, "\n")

	end := -1
	for idx := len(lines) - 1; idx >= 0; idx-- {
		if hexBytePattern.MatchString(lines[idx]) {
			end = idx
			break
		}
	}

	if end == -1 {
		return ""
	}

	start := end
	for start > 0 {
		trimmed := strings.TrimSpace(lines[start-1])
		if !addressLineStart.MatchString(trimmed) && !hexBytePattern.MatchString(trimmed) {
			break
		}
		start--
	}

	return strings.Join(lines[start:end+1], "\n")
}

func ExtractCharacters(contents string) (string, error) {
	region := extractDumpRegion(contents)
	if region == "" {
		return "", fmt.Errorf("no VGA dump lines found")
	}

	matches := hexBytePattern.FindAllStringSubmatch(region, -1)

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

	characters := builder.String()
	if characters == "" {
		return "", nil
	}

	var formatted []string
	for start := 0; start < len(characters); start += vgaColumns {
		end := start + vgaColumns
		if end > len(characters) {
			end = len(characters)
		}
		formatted = append(formatted, strings.TrimRight(characters[start:end], " "))
	}

	return strings.Join(formatted, "\n"), nil
}

func Usage(binName string) string {
	return fmt.Sprintf("usage: %s <dump_path>\n", filepath.Base(binName))
}
