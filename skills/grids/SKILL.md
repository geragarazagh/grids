---
name: grids
description: "Computes exact Grids proportion coordinates (halves, quarters, golden ratio, thirds, 8-pt grid) and controls the Grids screen overlay on macOS via grids-cli. Use when aligning windows or graphics to screen proportions, toggling Grids, or customizing Grids."
license: MIT
compatibility: "macOS 13 or later (Apple Silicon) with Grids installed (brew install geragarazagh/tap/grids or /Applications/Grids.app)."
---

# Grids

Queries exact proportion coordinates and controls the running Grids overlay from the command line (`grids-cli`).

## Locate the CLI

Check in order; use the first that exits 0:

```sh
grids-cli --version
/Applications/Grids.app/Contents/MacOS/Grids --version
```

If neither exists, tell the user how to install it (`brew install geragarazagh/tap/grids`) and stop.

## Common tasks

1. **Compute exact guide coordinates** (works headless even when Grids is not running; defaults to the main display size):
   ```sh
   grids-cli lines --json
   grids-cli lines 1728x1117 --mode golden --json
   ```
   Modes: `all`, `halves`, `golden`, `thirds`, `fine`.
2. **Control the running overlay** (requires `Grids.app` running):
   ```sh
   grids-cli show golden
   grids-cli hide
   grids-cli toggle
   grids-cli status --json
   ```

## Rebuilding from source

Clone `https://github.com/geragarazagh/grids`, read `AGENTS.md`, edit `main.swift`, and run `./build` (requires only Xcode Command Line Tools for ad-hoc builds).
