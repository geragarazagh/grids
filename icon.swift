// Grids app icon, drawn with Core Graphics at 1024 px on Apple's macOS grid (824 px plate, dark):
// the app's own screen in miniature, every guide in the colour the app draws it.
// Colours: Apple system colours in Dark mode (NSColor.system*):
//   red #FF4245 = 1/2, orange #FF9230 = 1/4, yellow #FFD600 = golden ratio, green #30D158 = 1/3,
//   blue #0091FF = fine grid. Draw order as in the app: fine grid, halves, quarters, golden, thirds.
// Math: positions are fractions of the plate, as on screen. The fine grid splits the plate into 24
// cells (24 = lcm of 2, 3, 4, 8), so the halves, quarters and thirds all fall on fine lines; every
// 4th fine line is brighter, as the app's 32 pt lines are. Coloured lines are 8 px wide: in the Dock
// (64 pt = 128 px) that is exactly 1 device pixel, the same weight the lines have on screen.
// Usage: ./build runs this.

import AppKit

func hex(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let red = hex(0xFF4245), orange = hex(0xFF9230), yellow = hex(0xFFD600), green = hex(0x30D158)
let phi = (sqrt(5.0) - 1) / 2
let p = CGRect(x: 100, y: 100, width: 824, height: 824)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let c = NSGraphicsContext.current!.cgContext

c.addPath(CGPath(roundedRect: p, cornerWidth: 185, cornerHeight: 185, transform: nil)); c.clip()
let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [hex(0x2C2C2E), hex(0x0F0F10)] as CFArray, locations: [0, 1])!
c.drawLinearGradient(g, start: CGPoint(x: 0, y: p.maxY), end: CGPoint(x: 0, y: p.minY), options: [])

// Image y runs up, the screen's y runs down: f is measured from the top, as the app's labels are.
func cross(_ f: CGFloat, _ col: CGColor, _ w: CGFloat) {
    c.setFillColor(col)
    c.fill(CGRect(x: p.minX + p.width * f - w / 2, y: p.minY, width: w, height: p.height))
    c.fill(CGRect(x: p.minX, y: p.maxY - p.height * f - w / 2, width: p.width, height: w))
}
for i in 1..<24 { cross(CGFloat(i) / 24, hex(0x0091FF, i % 4 == 0 ? 0.45 : 0.2), 4) }
cross(0.5, red, 8)
for f: CGFloat in [0.25, 0.75] { cross(f, orange, 8) }
for f in [1 - phi, phi] { cross(f, yellow, 8) }
for f: CGFloat in [1.0 / 3, 2.0 / 3] { cross(f, green, 8) }

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
