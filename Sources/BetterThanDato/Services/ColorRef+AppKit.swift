import AppKit
import DatoCore
import SwiftUI

extension ColorRef {
    init(nsColor: NSColor?) {
        guard let color = nsColor?.usingColorSpace(.sRGB) else {
            self = .gray
            return
        }
        self.init(red: Double(color.redComponent), green: Double(color.greenComponent), blue: Double(color.blueComponent))
    }
}

extension Color {
    init(_ ref: ColorRef) {
        self.init(.sRGB, red: ref.red, green: ref.green, blue: ref.blue)
    }
}

extension NSColor {
    convenience init(_ ref: ColorRef) {
        self.init(srgbRed: ref.red, green: ref.green, blue: ref.blue, alpha: 1)
    }
}
