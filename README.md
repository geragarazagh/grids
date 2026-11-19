<picture><source media="(prefers-color-scheme: dark)" srcset="docs/icon-github-dark.png"><img src="docs/icon-github.png" width="128" alt="Grids icon"></picture>

# Grids: screen grid overlay for Mac

Grids is a free, open source menu bar app for macOS that draws a grid over the whole screen: halves and quarters, the golden ratio, thirds and an 8-pt grid. Clicks pass through the lines to the windows underneath. It is intended for checking layout and proportion in apps that have no guides or snapping of their own.

![Grids in use: Halves and Quarters over the Earthrise photo of Apollo 8, the lunar horizon on the lower quarter line, Earth on the upper one, the Grids menu open, dark appearance](docs/scene.webp)

## Install

**Mac** (Apple silicon, macOS 13 or later): download [`Grids.dmg`](https://github.com/geragarazagh/grids/releases/latest/download/Grids.dmg) (1.9 MB), open it and drag `Grids.app` to Applications. Later versions arrive through Check for Updates.

Or with [Homebrew](https://brew.sh):

```sh
brew install geragarazagh/tap/grids
```

## Use

Opening Grids draws the grid on every display; quitting removes it. The menu bar icon switches the modes.

## For advanced users and language models

### Modes

The menu lists five modes, then Check for Updates… and Quit Grids. Choosing the checked mode again hides the grid; choosing any mode shows it again. Every launch starts in All: the mode is not saved. Each fraction below is drawn twice: as a vertical line at that fraction of the screen’s width and as a horizontal line at that fraction of its height.

- All: the lines of the four modes below together.
- Halves &amp; Quarters: red at 1/2, orange at 1/4 and 3/4.
- Golden Ratio: red at 1/2, yellow at 0.382 and 0.618.
- Thirds: red at 1/2, green at 1/3 and 2/3.
- 8-pt Grid: red at 1/2, blue every 8 points from the top left corner.

### How it works

- Each display gets one borderless, transparent window the size of the whole screen, menu bar and Dock included. The window sits at the screen saver window level, in every Space and over full-screen apps, and ignores mouse events, which lets clicks through.
- When a display is connected, removed or rearranged, or its resolution changes, the windows are rebuilt for the new layout.
- Each line is one device pixel wide, on the nearest device pixel. Beside each red, orange, yellow and green line, one device pixel to the right or below, a black line at 50 % opacity keeps it visible over light content.
- Each of these lines carries a label with its position in points from the top left corner of the screen: at the bottom edge for a vertical line, at the right edge for a horizontal one. A label is a capsule in the line’s color with black or white digits, chosen by the color’s luminance. A position ending in .5 means the line sits on an odd device pixel of a 2× (Retina) display.
- Colors are the system colors of macOS (`NSColor.systemRed`, `systemOrange`, `systemYellow`, `systemGreen`, `systemBlue`) as macOS gives them for the light or dark appearance, in rainbow order from the coarsest division to the finest, the order of the menu. Blue lines are drawn at 20 % opacity, every fourth one (every 32 points) at 45 %.
- The golden ratio lines stand at 1/φ² ≈ 0.382 and 1/φ ≈ 0.618, where φ = (1 + √5) / 2.
- Grids is an agent app (`LSUIElement`): no Dock icon and no app menu; its menu bar icon is the SF Symbol `rectangle.split.3x3`. It registers no keyboard shortcut.

### Questions

#### Can the grid be resized or recolored?

No. Fractions, colors and line widths are fixed in the code, and every display shows the same mode.

#### Does the grid appear in screenshots and screen recordings?

Yes, while it is shown. Grids does not exclude its windows from screen capture (`NSWindow.sharingType` keeps its default), so macOS captures them like any other window.

### Updates

The update check is the only network request Grids makes. Once a day the Sparkle framework reads `appcast.xml`, the feed attached to the latest GitHub release; nothing about the Mac is sent. When a newer version is out, a window shows it with Install Update, Remind Me Later and Skip This Version; nothing is downloaded before Install Update. Check for Updates… in the menu checks at once.

The feed and the disk image are signed with an EdDSA key, and Sparkle installs only an app that carries the same Developer ID signature.

### Settings and removal

Grids has no settings of its own. Sparkle keeps three values in the defaults domain `com.geragaraza.grids`: `SUHasLaunchedBefore`, `SULastCheckTime` and `SUUpdateGroupIdentifier`. Its network session is memory-only (an ephemeral `URLSession`), so no cache or cookies are written to disk.

To remove Grids: Quit Grids in its menu, move `Grids.app` to the Trash and delete its defaults with this command:

```sh
defaults delete com.geragaraza.grids
```

For a copy installed with Homebrew, this command quits Grids, deletes the app and moves its preferences file to the Trash:

```sh
brew uninstall --zap grids
```

### Details

- Version: 1.3.
- Bundle ID: `com.geragaraza.grids`.
- Download: `Grids.dmg`, 1.9 MB.
- Requires: Apple silicon, macOS 13 or later.
- Permissions: none.
- Signed with a Developer ID and notarized by Apple.
- Code: Swift and AppKit in two files, `main.swift` and `updates.swift`, about 250 lines; Sparkle 2.10.1 for updates.
- License: MIT. Sparkle’s MIT license is in `THIRD-PARTY-LICENSES.md`, in the repository and inside the app.

### Build

Needs the Swift compiler (Command Line Tools or Xcode) and Xcode 26 or later in Applications, whose actool and Icon Composer build the light and dark icon. The first build downloads the Sparkle framework from its GitHub release and checks it against a pinned SHA-256 checksum.

    ./build

Search terms: grid overlay for Mac, screen grid macOS, golden ratio overlay, rule of thirds overlay, center lines overlay, proportion grid, composition grid, 8-pt grid overlay, 8pt grid, screen guides, layout guides over any app, grid over video editor, menu bar app.
