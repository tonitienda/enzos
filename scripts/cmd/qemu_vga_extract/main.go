package main

import (
	"fmt"
	"os"

	"enzos/scripts/vga"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprint(os.Stderr, vga.Usage(os.Args[0]))
		os.Exit(1)
	}

	dumpPath := os.Args[1]
	contents, err := os.ReadFile(dumpPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "dump file error: %v\n", err)
		os.Exit(1)
	}

	chars, err := vga.ExtractCharacters(string(contents))
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}

	fmt.Println(chars)
}
