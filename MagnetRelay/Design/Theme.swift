import SwiftUI
import AppKit

// MARK: - Palette

extension Color {
    /// The Relay palette. `accent` is reserved for the single active thing on screen
    /// (selected tile, step progress, error dot, mark pole tips); `ready` only for the
    /// connected dot and "on" switch tint.
    enum Relay {
        static let background = Color(light: NSColor(hex: "F6F5F3"), dark: NSColor(hex: "1C1C1E"))
        static let card = Color(light: NSColor(hex: "FFFFFF"), dark: NSColor(hex: "2C2C2E"))
        static let ink = Color(light: NSColor(hex: "1D1D1F"), dark: NSColor(hex: "F5F5F7"))
        static let secondary = Color(light: NSColor(hex: "6E6E73"), dark: NSColor(hex: "98989D"))
        static let hairline = Color(light: NSColor(white: 0, alpha: 0.09), dark: NSColor(white: 1, alpha: 0.10))
        static let accent = Color(light: NSColor(hex: "E5484D"), dark: NSColor(hex: "FF6369"))
        static let ready = Color(light: NSColor(hex: "2DA44E"), dark: NSColor(hex: "3FB950"))
    }
}

// MARK: - Typography

extension Font {
    enum Relay {
        /// Apply with `.tracking(RelayMetrics.headingTracking)` (−0.02em at 22pt).
        static let heading = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 13)
        static let secondary = Font.system(size: 12)
        static let label = Font.system(size: 13, weight: .semibold)
    }
}

// MARK: - Metrics

enum RelayMetrics {
    static let gutter: CGFloat = 24
    static let cardRadius: CGFloat = 10
    static let rowHeight: CGFloat = 40
    static let windowSize = CGSize(width: 460, height: 430)
    /// −0.02em at the 22pt heading size.
    static let headingTracking: CGFloat = -0.44
    static let hairlineWidth: CGFloat = 0.5
}

// MARK: - Color Initializers

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? dark : light
        })
    }
}

extension NSColor {
    convenience init(hex: String, alpha: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(alpha))
    }

    convenience init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.init(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}
