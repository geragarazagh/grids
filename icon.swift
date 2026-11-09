// Grids app icon: the app's own screen in miniature, every guide in the colour the app draws it.
// Since 2026-11-09 it is an Icon Composer icon (macOS 26+ switches it with the theme, Apple's way): this draws only
// the picture, light.png and dark.png, 1024 px, transparent; the plate is the system's own fill (./build writes
// icon.json, actool makes Assets.car and the .icns that macOS 13-15 show, Apple's light rendition).
// Colours: Apple system colours as NSColor.system* gives them in each appearance (read on macOS 27):
//   red 1/2, orange 1/4, yellow golden ratio, green 1/3, blue fine grid. Draw order as in the app.
// Math: positions are fractions of the canvas, as on screen. The fine grid splits it into 24
// cells (24 = lcm of 2, 3, 4, 8), so the halves, quarters and thirds all fall on fine lines; every
// 4th fine line is brighter, as the app's 32 pt lines are. Coloured lines are 8 px wide on the old 824 px plate,
// which is the whole canvas now, so everything is scaled by 1024/824.
// Usage: ./build runs this: icon <dir> writes <dir>/light.png and <dir>/dark.png.

import AppKit

func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let phi = (sqrt(5.0) - 1) / 2
let p = CGRect(x: 100, y: 100, width: 824, height: 824)

func render(_ light: Bool, _ path: String) {
    let red = hex(light ? 0xFF383C : 0xFF4245), orange = hex(light ? 0xFF8D28 : 0xFF9230)
    let yellow = hex(light ? 0xFFCC00 : 0xFFD600), green = hex(light ? 0x34C759 : 0x30D158), blue: UInt32 = light ? 0x0088FF : 0x0091FF
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let c = NSGraphicsContext.current!.cgContext
    c.scaleBy(x: 1024 / 824, y: 1024 / 824); c.translateBy(x: -100, y: -100)
    // Image y runs up, the screen's y runs down: f is measured from the top, as the app's labels are.
    func cross(_ f: CGFloat, _ col: CGColor, _ w: CGFloat) {
        c.setFillColor(col)
        c.fill(CGRect(x: p.minX + p.width * f - w / 2, y: p.minY, width: w, height: p.height))
        c.fill(CGRect(x: p.minX, y: p.maxY - p.height * f - w / 2, width: p.width, height: w))
    }
    for i in 1..<24 { cross(CGFloat(i) / 24, hex(blue, i % 4 == 0 ? 0.45 : 0.2), 4) }
    cross(0.5, red, 8)
    for f: CGFloat in [0.25, 0.75] { cross(f, orange, 8) }
    for f in [1 - phi, phi] { cross(f, yellow, 8) }
    for f: CGFloat in [1.0 / 3, 2.0 / 3] { cross(f, green, 8) }
    NSGraphicsContext.current = nil
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(true, CommandLine.arguments[1] + "/light.png")
render(false, CommandLine.arguments[1] + "/dark.png")
