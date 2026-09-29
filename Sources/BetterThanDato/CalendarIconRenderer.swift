import AppKit

/// Draws the menu bar icon: a small calendar page with today's day number.
/// Template image, so macOS tints it for light, dark and tinted menu bars.
enum CalendarIconRenderer {
    static func image(day: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 17, height: 16), flipped: false) { _ in
            let page = NSRect(x: 1, y: 1, width: 15, height: 14)
            let outline = NSBezierPath(roundedRect: page, xRadius: 3, yRadius: 3)
            let bandHeight: CGFloat = 3.5
            NSColor.black.set()

            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            NSRect(x: page.minX, y: page.maxY - bandHeight, width: page.width, height: bandHeight).fill()
            NSGraphicsContext.restoreGraphicsState()

            outline.lineWidth = 1.2
            outline.stroke()

            let text = "\(day)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let size = text.size(withAttributes: attributes)
            let bodyHeight = page.height - bandHeight
            text.draw(
                at: NSPoint(x: page.midX - size.width / 2, y: page.minY + (bodyHeight - size.height) / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
