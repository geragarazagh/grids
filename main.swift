// Grids: a fixed, click-through grid over the whole screen, for placing windows and panels by
// proportion in apps that have no snapping of their own. Open the app = grid on; quit = grid gone.
// Nothing of the grid is saved (only Sparkle keeps its last update check), nothing resizes: every launch starts
// with All, on the full screen.
// It lives in the menu bar, not the Dock (LSUIElement).
//
// Colours are Apple's system colours (NSColor.system*, resolved by macOS for the current
// appearance), in rainbow order from the coarsest division to the finest, and the menu follows the
// same order: red 1/2, orange 1/4, yellow golden ratio, green 1/3, blue 8 pt grid (8 pt is Apple's
// layout step).
// Each line is exactly 1 device pixel on a pixel boundary; a half-transparent black pixel beside it
// keeps it visible over light content. Labels give the line's position in points from the top-left
// corner, exactly as drawn (a .5 means the line sits on the odd device pixel).

import AppKit

enum Mode: Int, CaseIterable {
    case all, halves, golden, thirds, fine
    var title: String {
        switch self {
        case .all: return "All"
        case .halves: return "Halves & Quarters"
        case .golden: return "Golden Ratio"
        case .thirds: return "Thirds"
        case .fine: return "8-pt Grid"
        }
    }
}

let phi = (sqrt(5.0) - 1) / 2   // 0.618...

struct Guide { let f: CGFloat; let color: NSColor }

func guides(_ m: Mode) -> [Guide] {
    let half = [Guide(f: 0.5, color: .systemRed)]
    let quarters = [0.25, 0.75].map { Guide(f: $0, color: .systemOrange) }
    let golden = [1 - phi, phi].map { Guide(f: $0, color: .systemYellow) }
    let thirds = [1.0 / 3, 2.0 / 3].map { Guide(f: $0, color: .systemGreen) }
    switch m {
    case .all: return half + quarters + golden + thirds
    case .halves: return half + quarters
    case .golden: return half + golden
    case .thirds: return half + thirds
    case .fine: return half
    }
}

final class GridView: NSView {
    var mode = Mode.all { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = window?.backingScaleFactor ?? 2, px = 1 / s
        let W = bounds.width, H = bounds.height
        let shade = NSColor.black.withAlphaComponent(0.5).cgColor
        func snap(_ v: CGFloat) -> CGFloat { (v * s).rounded() / s }   // nearest device pixel
        func fill(_ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(r) }

        if mode == .all || mode == .fine {
            let blue = NSColor.systemBlue
            for x in stride(from: 8, to: Int(W), by: 8) {
                fill(CGRect(x: CGFloat(x), y: 0, width: px, height: H), blue.withAlphaComponent(x % 32 == 0 ? 0.45 : 0.2).cgColor)
            }
            for y in stride(from: 8, to: Int(H), by: 8) {
                fill(CGRect(x: 0, y: CGFloat(y), width: W, height: px), blue.withAlphaComponent(y % 32 == 0 ? 0.45 : 0.2).cgColor)
            }
        }
        for g in guides(mode) {
            let x = snap(W * g.f), y = snap(H * g.f), c = g.color.cgColor
            fill(CGRect(x: x + px, y: 0, width: px, height: H), shade); fill(CGRect(x: x, y: 0, width: px, height: H), c)
            fill(CGRect(x: 0, y: y + px, width: W, height: px), shade); fill(CGRect(x: 0, y: y, width: W, height: px), c)
            badge(num(x), color: g.color, anchor: CGPoint(x: x, y: H - 3), vertical: true)
            badge(num(y), color: g.color, anchor: CGPoint(x: W - 3, y: y), vertical: false)
        }
    }

    func num(_ v: CGFloat) -> String { v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v) }

    // A small capsule in the line's own colour, like a macOS badge; text black or white,
    // whichever reads better on that colour.
    func badge(_ t: String, color: NSColor, anchor: CGPoint, vertical: Bool) {
        let c = color.usingColorSpace(.sRGB)!
        let lum = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        let a: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: lum > 0.5 ? NSColor.black : NSColor.white]
        let str = NSAttributedString(string: t, attributes: a), sz = str.size()
        let w = sz.width + 8, h = sz.height + 2
        let r = vertical
            ? CGRect(x: anchor.x - w / 2, y: anchor.y - h, width: w, height: h)   // centred on the line, at the bottom edge
            : CGRect(x: anchor.x - w, y: anchor.y - h / 2, width: w, height: h)   // centred on the line, at the right edge
        color.setFill(); NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill()
        str.draw(at: CGPoint(x: r.minX + 4, y: r.minY + 1))
    }
}

@MainActor final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var windows: [NSWindow] = []
    var mode = Mode.all
    var on = true

    func applicationDidFinishLaunching(_ n: Notification) {
        statusMenu()
        build()
        _ = Updates.shared   // starts the daily check
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.build() } }
    }

    func build() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { scr in
            let w = NSWindow(contentRect: scr.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.setFrame(scr.frame, display: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            let v = GridView(frame: CGRect(origin: .zero, size: scr.frame.size)); v.mode = mode
            w.contentView = v
            if on { w.orderFrontRegardless() }
            return w
        }
    }

    var item: NSStatusItem!

    func statusMenu() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "rectangle.split.3x3", accessibilityDescription: "Grids")!
        img.isTemplate = true
        item.button?.image = img
        let m = NSMenu()
        for k in Mode.allCases {
            let i = NSMenuItem(title: k.title, action: #selector(pick(_:)), keyEquivalent: "")
            i.tag = k.rawValue; i.target = self; i.state = k == mode ? .on : .off
            m.addItem(i)
            if k == .all { m.addItem(.separator()) }
        }
        m.addItem(.separator())
        let u = NSMenuItem(title: "Check for Updates…", action: #selector(Updates.check), keyEquivalent: "")
        u.target = Updates.shared
        m.addItem(u)
        m.addItem(NSMenuItem(title: "Quit Grids", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        m.delegate = self
        item.menu = m
    }

    // Opening the menu is opening the app: an update waiting behind other windows comes to the front.
    func menuDidClose(_ menu: NSMenu) { Updates.shared.appOpened() }

    // Picking the checked mode again turns the grid off without quitting:
    // no ticks = nothing on screen; any mode brings it back.
    @objc func pick(_ i: NSMenuItem) {
        let k = Mode(rawValue: i.tag)!
        on = !(on && k == mode)
        mode = k
        windows.forEach {
            ($0.contentView as? GridView)?.mode = mode
            if on { $0.orderFrontRegardless() } else { $0.orderOut(nil) }
        }
        item.menu?.items.forEach { if $0.action == #selector(pick(_:)) { $0.state = on && $0.tag == i.tag ? .on : .off } }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let d = App(); app.delegate = d
    app.setActivationPolicy(.accessory)
    app.run()
}
