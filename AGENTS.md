# Agent Instructions

These conventions apply to all files in this repository:

- Write documentation in Markdown using Title Case headings.
- Favor short paragraphs and bullet lists for clarity.
- Use fenced code blocks with explicit language hints when showing commands or code.
- Keep the tone educational: explain why something matters, not just what to type.
- Keep this guide in sync with project changes so future contributors do not follow outdated practices.
- When describing scripts, note the intent, required tools, and how to run them.
- Keep host-side automation in Bash for orchestration (building, Docker, QEMU) and use the single Go entrypoint at `cmd/main.go` for monitor interactions, tests, and other complex tasks like VNC screenshots.
- Avoid inline scripts in GitHub workflows or composite actions; point steps at checked-in scripts instead.

## Project Context

- EnzOS is a tiny teaching OS; briefly explain how new documentation or tooling supports learning the platform (e.g., simplifying boot flows or clarifying build steps).
- When adding host-side tools or test helpers that run outside EnzOS, prefer Golang for its portability and ease of cross-platform builds; call out the rationale when choosing a different language.
