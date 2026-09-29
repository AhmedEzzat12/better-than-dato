// Renders the app icon into Resources/AppIcon.icns (plus docs/icon.png for the README).
// Usage: swift scripts/make-icon.swift   (run from the repo root)
//
// Drawn as vectors on a 1024 grid and rendered separately at every size, so small sizes stay crisp.
// Motif: a calendar card whose three agenda rows use three account colors — every account, one agenda.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    ).cgColor
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

/// Draws on a 1024×1024 canvas, origin bottom-left (Apple's macOS icon grid: 824pt tile, 100pt margin).
func drawIcon(_ ctx: CGContext) {
    // Tile with drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = rounded(tile, 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x3A2BC4))
    ctx.fillPath()
    ctx.restoreGState()

    // Tile gradient + soft top highlight.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        linearGradient([color(0x6E8DFF), color(0x3A2BC4)]),
        start: CGPoint(x: 180, y: 924), end: CGPoint(x: 844, y: 100), options: []
    )
    ctx.drawLinearGradient(
        linearGradient([color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)]),
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: []
    )
    ctx.restoreGState()

    // Calendar card.
    let card = CGRect(x: 242, y: 214, width: 540, height: 560)
    let cardPath = rounded(card, 70)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: color(0x10083A, 0.35))
    ctx.addPath(cardPath)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()

    // Coral header band with two binder rings.
    let bandHeight: CGFloat = 150
    let bandBottom = card.maxY - bandHeight
    ctx.saveGState()
    ctx.clip(to: CGRect(x: card.minX, y: bandBottom, width: card.width, height: bandHeight))
    ctx.drawLinearGradient(
        linearGradient([color(0xFF7A66), color(0xF0413A)]),
        start: CGPoint(x: 0, y: card.maxY), end: CGPoint(x: 0, y: bandBottom), options: []
    )
    ctx.restoreGState()
    for x in [card.minX + 150, card.maxX - 150] {
        ctx.setFillColor(color(0xFFFFFF, 0.92))
        ctx.fillEllipse(in: CGRect(x: x - 24, y: bandBottom + bandHeight / 2 - 24, width: 48, height: 48))
    }

    // Three agenda rows, one per account color. The first is "happening now" (tinted background).
    let accents: [UInt32] = [0xFF9F0A, 0x30D158, 0x0A84FF]
    let titleWidths: [CGFloat] = [300, 240, 280]
    let timeWidths: [CGFloat] = [150, 190, 130]
    let rowHeight: CGFloat = 76
    let rowSpacing: CGFloat = 118
    let bodyHeight = bandBottom - card.minY
    let firstCenter = bandBottom - (bodyHeight - (2 * rowSpacing + rowHeight)) / 2 - rowHeight / 2

    for index in accents.indices {
        let centerY = firstCenter - CGFloat(index) * rowSpacing
        let left = card.minX + 60
        if index == 0 {
            ctx.addPath(rounded(CGRect(x: card.minX + 30, y: centerY - 54, width: card.width - 60, height: 108), 26))
            ctx.setFillColor(color(accents[index], 0.14))
            ctx.fillPath()
        }
        ctx.addPath(rounded(CGRect(x: left, y: centerY - rowHeight / 2, width: 18, height: rowHeight), 9))
        ctx.setFillColor(color(accents[index]))
        ctx.fillPath()

        ctx.addPath(rounded(CGRect(x: left + 44, y: centerY + 4, width: titleWidths[index], height: 28), 14))
        ctx.setFillColor(color(0x2B2A3D, 0.88))
        ctx.fillPath()

        ctx.addPath(rounded(CGRect(x: left + 44, y: centerY - 34, width: timeWidths[index], height: 20), 10))
        ctx.setFillColor(color(0x8E8CA8, 0.7))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }

try render(pixels: 512).write(to: URL(fileURLWithPath: "docs/icon.png"))
print("Wrote Resources/AppIcon.icns and docs/icon.png")
