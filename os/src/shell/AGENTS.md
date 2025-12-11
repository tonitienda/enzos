# Agent Instructions for Shell

- Keep shell command dispatch simple; prefer straightforward conditional checks over heavy registries while the command set is tiny.
- Preserve tab-based indentation and avoid heap use when adding shell features.
- When adding new commands, document their learning value (e.g., demonstrates argument parsing or terminal output) in commit messages or PR notes.
- Treat text inside double quotes as a single argument and strip the quotes so commands like `echo "Hello, World"` mirror typical shell behavior without extra branching.
- When stripping quotes, record the delimiter before inserting a string terminator so later arguments are not skipped when you move past the delimiter.
- Route shell output through `shell_output_*` helpers so redirection can capture text into the in-memory filesystem without painting the terminal.
- History and alias tables are intentionally tiny (32 and 16 entries, respectively) to show bounded data structures; keep them stack-allocated and avoid reallocations.
- Preserve escape handling for whitespace, newlines, tabs, and embedded quotes so the tokenizer examples in the README stay accurate.
