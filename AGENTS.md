# Agent Instructions

These conventions apply to all files in this repository:

- Write documentation in Markdown using Title Case headings.
- Favor short paragraphs and bullet lists for clarity.
- Use fenced code blocks with explicit language hints when showing commands or code.
- Keep the tone educational: explain why something matters, not just what to type.
- Keep this guide in sync with project changes so future contributors do not follow outdated practices.
- When describing scripts, note the intent, required tools, and how to run them.
- Keep host-side automation in Bash for orchestration (building, Docker, QEMU) and use the single Go entrypoint at `cmd/main.go` for monitor interactions, tests, and other complex tasks like VNC screenshots.
- Use Go to observe and test the OS; keep ISO creation and release artifact steps in Bash without introducing Go dependencies.
- Avoid inline scripts in GitHub workflows or composite actions; point steps at checked-in scripts instead.
- Integration screenshots live in `qemu-screen-*.ppm` with PNG siblings generated for CI artifacts, PR comments, and release bundles.

## Testing Notes

- The shell integration tests focus on two scenarios: verifying the OS is ready (prompt appears) and confirming `echo` output. Each scenario should capture its own screenshot after the assertions pass to keep artifacts aligned with the checks.
- Treat quoted arguments as single tokens in shell scenarios (e.g., `echo "Hello, World"` prints `Hello, World` without quotes); update expectations and fixtures whenever argument parsing changes.
- Express positive and negative expectations in each scenario definition (for example, use `Unexpected` to block echoed quotes) instead of adding ad-hoc `if` statements inside the loop that runs the examples.

## Project Context

- EnzOS is a tiny teaching OS; briefly explain how new documentation or tooling supports learning the platform (e.g., simplifying boot flows or clarifying build steps).
- When adding host-side tools or test helpers that run outside EnzOS, prefer Golang for its portability and ease of cross-platform builds; call out the rationale when choosing a different language.
