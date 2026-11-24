---
name: grids
description: "Computes exact Grids proportion coordinates (halves, quarters, golden ratio, thirds, 8-pt grid) and controls the Grids screen overlay on macOS via grids-cli. Use when aligning windows or graphics to screen proportions, toggling Grids, or customizing Grids."
license: MIT
compatibility: "macOS 13 or later (Apple Silicon) with Grids installed (brew install geragarazagh/tap/grids or /Applications/Grids.app)."
---

# Grids

Queries exact proportion coordinates and controls the running Grids overlay from the command line (`grids-cli`).

## Locate the CLI

Check in order; use the first that exits 0. Use `--help`, never `--version`, and read the app's version from its Info.plist before running its binary: Grids before 1.4 has no command line at all, so it takes every flag (`--help` and `--version` alike) as a plain start and opens its window instead of failing.

```sh
grids-cli --help
defaults read /Applications/Grids.app/Contents/Info CFBundleShortVersionString
/Applications/Grids.app/Contents/MacOS/Grids --help
```

`grids-cli` exists only in versions that have the command line, so it is safe to try first. Run the third line only if the second prints 1.4 or newer; if it prints an older version, tell the user once to update Grids (Check for Updates in its menu, or `brew upgrade --cask geragarazagh/tap/grids`) and stop. If none works, tell the user how to install it (`brew install geragarazagh/tap/grids`) and stop.

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
