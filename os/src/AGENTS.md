# Agent Instructions for src

Guidelines for kernel and driver code under `src/`:

- Write kernel logic in C or small x86 assembly snippets; avoid C++ or libc features that assume a hosted environment.
- Keep the cross-compiler guards (`__i386__` and `ALLOW_HOST_TOOLCHAIN`) intact when touching files so the build fails fast on the wrong toolchain.
- Match the existing tabbed indentation and compact helpers (`static inline` or `static` functions) to minimize footprint and keep symbols private.
- Avoid heap allocation and dynamic buffers; prefer fixed-size stacks and simple string routines like the existing `strlen`/`kstrlen` helpers.
- When expanding shell commands or drivers, favor straightforward control flow with early returns and keep VGA/keyboard access confined to the driver layer.
- Explain how a change helps readers understand OS fundamentals (e.g., why a new command demonstrates input handling or VGA writes).
- Terminal helpers now expose cursor positioning and a clear routine; reuse them from the shell instead of duplicating VGA buffer loops.
