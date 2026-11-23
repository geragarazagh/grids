# AGENTS.md — Grids

Click-through proportion grid overlay for macOS (halves, quarters, golden ratio, thirds, 8-pt grid) in plain Swift + AppKit. No Xcode project; `./build` compiles directly with `swiftc`.

## Architecture

- `main.swift` — `Mode`, `guides()`, `GridView` (1-device-pixel snapped lines + shadow + contrast badges), menu bar `NSStatusItem`, borderless screen-saver-level click-through windows.
- `cli.swift` — `grids-cli` (`lines`, `show`, `hide`, `toggle`, `status`, `--version`, `--help`) + `GridsControl` `0600` Unix socket (`LOCAL_PEERTOKEN` verified).
- `updates.swift` — Sparkle 2.10.1 updater (ephemeral `URLSession`).
- `icon.swift` — procedural icon generator.

## Build

- `./build` — builds ad-hoc signed `Grids.app` (`-target arm64-apple-macos13.0`). Works with Xcode Command Line Tools alone (`iconutil` fallback). Full Xcode is used for `Assets.car` (required when `SIGN_ID` is set).

## Invariants

- **Zero state on disk**: nothing saved beyond Sparkle's update check; every launch starts with `All`.
- **Zero permissions**: needs neither Accessibility nor Screen Recording.
- **Customizing locally**: edit guide fractions/colours in `main.swift`, run `./build`, replace `/Applications/Grids.app`.
