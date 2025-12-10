package tools

import (
	"bufio"
	"fmt"
	"image"
	"image/png"
	"io"
	"os"
	"strconv"
	"strings"
)

// ConvertPPMToPNG converts a raw binary PPM (P6) file to a PNG image.
func ConvertPPMToPNG(ppmPath, pngPath string) error {
	ppmFile, err := os.Open(ppmPath)
	if err != nil {
		return fmt.Errorf("open PPM file: %w", err)
	}
	defer ppmFile.Close()

	reader := bufio.NewReader(ppmFile)

	magic, err := readPPMToken(reader)
	if err != nil {
		return fmt.Errorf("read PPM magic: %w", err)
	}
	if magic != "P6" {
		return fmt.Errorf("unsupported PPM format %q", magic)
	}

	widthToken, err := readPPMToken(reader)
	if err != nil {
		return fmt.Errorf("read PPM width: %w", err)
	}
	heightToken, err := readPPMToken(reader)
	if err != nil {
		return fmt.Errorf("read PPM height: %w", err)
	}

	width, err := strconv.Atoi(widthToken)
	if err != nil || width <= 0 {
		return fmt.Errorf("invalid PPM width %q", widthToken)
	}
	height, err := strconv.Atoi(heightToken)
	if err != nil || height <= 0 {
		return fmt.Errorf("invalid PPM height %q", heightToken)
	}

	maxValToken, err := readPPMToken(reader)
	if err != nil {
		return fmt.Errorf("read PPM max value: %w", err)
	}
	maxVal, err := strconv.Atoi(maxValToken)
	if err != nil || maxVal != 255 {
		return fmt.Errorf("unsupported PPM max value %q", maxValToken)
	}

	pixelData := make([]byte, width*height*3)
	if _, err := io.ReadFull(reader, pixelData); err != nil {
		return fmt.Errorf("read PPM pixel data: %w", err)
	}

	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for i := 0; i < width*height; i++ {
		src := i * 3
		dst := i * 4
		img.Pix[dst] = pixelData[src]
		img.Pix[dst+1] = pixelData[src+1]
		img.Pix[dst+2] = pixelData[src+2]
		img.Pix[dst+3] = 255
	}

	pngFile, err := os.Create(pngPath)
	if err != nil {
		return fmt.Errorf("create PNG file: %w", err)
	}
	defer pngFile.Close()

	if err := png.Encode(pngFile, img); err != nil {
		return fmt.Errorf("encode PNG: %w", err)
	}

	return nil
}

func readPPMToken(reader *bufio.Reader) (string, error) {
	var builder strings.Builder

	// Skip whitespace and comments
	for {
		ch, err := reader.ReadByte()
		if err != nil {
			return "", err
		}

		if ch == '#' {
			if err := skipPPMComment(reader); err != nil {
				return "", err
			}
			continue
		}

		if !isWhitespace(ch) {
			builder.WriteByte(ch)
			break
		}
	}

	// Read until next whitespace
	for {
		ch, err := reader.ReadByte()
		if err != nil {
			if err == io.EOF {
				return builder.String(), nil
			}
			return "", err
		}

		if isWhitespace(ch) {
			return builder.String(), nil
		}
		builder.WriteByte(ch)
	}
}

func skipPPMComment(reader *bufio.Reader) error {
	for {
		ch, err := reader.ReadByte()
		if err != nil {
			return err
		}
		if ch == '\n' {
			return nil
		}
	}
}

func isWhitespace(ch byte) bool {
	switch ch {
	case ' ', '\n', '\t', '\r':
		return true
	default:
		return false
	}
}
