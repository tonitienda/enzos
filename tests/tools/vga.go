package tools

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

const vgaColumns = 80

var (
	hexBytePattern   = regexp.MustCompile(`\b0x?([0-9a-fA-F]{2})\b`)
	addressLineStart = regexp.MustCompile(`^[0-9a-fA-F]+:`)
)

func printableASCII(value int64) bool {
	return value >= 0x20 && value <= 0x7e
}

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

// ExtractVGAText parses QEMU monitor VGA buffer dump output and extracts the visible text.
func ExtractVGAText(contents string) (string, error) {
	region := extractDumpRegion(contents)
	if region == "" {
		return "", fmt.Errorf("no hex dump region found in monitor output")
	}

	// Remove addresses: extract only the part after the colon on each line
	lines := strings.Split(region, "\n")
	var dataOnly []string
	for _, line := range lines {
		if idx := strings.Index(line, ":"); idx >= 0 {
			dataOnly = append(dataOnly, line[idx+1:])
		}
	}
	cleanRegion := strings.Join(dataOnly, " ")

	matches := hexBytePattern.FindAllStringSubmatch(cleanRegion, -1)
	if len(matches) == 0 {
		return "", fmt.Errorf("no hex bytes found in dump region")
	}

	var chars []rune
	// VGA text mode: byte pairs of (character, attribute)
	// We want every even-indexed byte (0, 2, 4, ...) which are the characters
	for i := 0; i < len(matches); i++ {
		// Skip attribute bytes (odd indices)
		if i%2 == 1 {
			continue
		}

		charByte := matches[i][1]
		value, err := strconv.ParseInt(charByte, 16, 64)
		if err != nil {
			continue
		}

		if printableASCII(value) {
			chars = append(chars, rune(value))
		} else if value == 0x00 {
			chars = append(chars, ' ')
		} else {
			chars = append(chars, '?')
		}
	}

	var outputLines []string
	for i := 0; i < len(chars); i += vgaColumns {
		end := i + vgaColumns
		if end > len(chars) {
			end = len(chars)
		}
		line := strings.TrimRight(string(chars[i:end]), " ")
		outputLines = append(outputLines, line)
	}

	return strings.Join(outputLines, "\n"), nil
}
