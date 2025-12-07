# Agent Instructions for .github

These conventions apply to automation files under `.github`:

- Favor Bash for short workflow glue; start scripts with `set -euo pipefail` and keep commands readable over many chained subshells.
- Reuse the composite actions in `.github/actions` instead of duplicating logic in new workflows; add parameters when behavior must diverge.
- Preserve two-space indentation and descriptive job names in YAML so CI remains easy for new learners to follow.
- When adding tools that run on the GitHub runner, prefer small Go helpers that can be built inside the repo (aligns with our host-side language choice) and avoid sprinkling new npm dependencies.
- Store test artifacts and screenshots in the existing `pr-images` directory so PR comments keep working without path changes.
- Document why a workflow step is needed (e.g., how it prepares QEMU or captures VNC output) to reinforce the teaching focus of EnzOS.
