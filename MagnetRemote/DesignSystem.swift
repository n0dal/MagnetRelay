import SwiftUI

// MARK: - Color Tokens

extension Color {
    enum MR {
        // Accent colors - Teal/Cyan for network utility feel
        static let accent = Color(light: .init(red: 0.15, green: 0.55, blue: 0.60),
                                  dark: .init(red: 0.25, green: 0.70, blue: 0.75))
        static let accentMuted = Color(light: .init(red: 0.15, green: 0.55, blue: 0.60, alpha: 0.12),
                                       dark: .init(red: 0.25, green: 0.70, blue: 0.75, alpha: 0.20))

        // Backgrounds
        static let background = Color(light: .init(hex: "F8FAFB"),
                                      dark: .init(hex: "121315"))
        static let surface = Color(light: .init(hex: "FFFFFF"),
                                   dark: .init(hex: "1E1F23"))
        static let surfaceElevated = Color(light: .init(hex: "FFFFFF"),
                                           dark: .init(hex: "282A2E"))

        // Input fields - slightly elevated from background
        static let inputBackground = Color(light: .init(hex: "FFFFFF"),
                                           dark: .init(hex: "1A1B1F"))
        static let inputBackgroundFocused = Color(light: .init(hex: "FFFFFF"),
                                                  dark: .init(hex: "1E2024"))

        // Text hierarchy
        static let textPrimary = Color(light: .init(hex: "1A1D21"),
                                       dark: .init(hex: "F1F3F5"))
        static let textSecondary = Color(light: .init(hex: "5C6370"),
                                         dark: .init(hex: "A0A8B0"))
        static let textTertiary = Color(light: .init(hex: "8B939E"),
                                        dark: .init(hex: "6B7280"))

        // Dividers & borders
        static let divider = Color(light: .init(hex: "E5E8EB"),
                                   dark: .init(hex: "383A40"))
        static let border = Color(light: .init(hex: "D1D5DB"),
                                  dark: .init(hex: "4B4F56"))

        // Semantic colors
        static let success = Color(light: .init(red: 0.20, green: 0.60, blue: 0.35),
                                   dark: .init(red: 0.30, green: 0.75, blue: 0.45))
        static let error = Color(light: .init(red: 0.85, green: 0.25, blue: 0.25),
                                 dark: .init(red: 0.95, green: 0.40, blue: 0.40))
        static let warning = Color(light: .init(red: 0.85, green: 0.60, blue: 0.20),
                                   dark: .init(red: 0.95, green: 0.70, blue: 0.30))
    }
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
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    convenience init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.init(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

// MARK: - Typography

extension Font {
    enum MR {
        static let largeTitle = Font.system(size: 26, weight: .semibold)
        static let title1 = Font.system(size: 22, weight: .semibold)
        static let title2 = Font.system(size: 18, weight: .semibold)
        static let title3 = Font.system(size: 16, weight: .medium)
        static let headline = Font.system(size: 14, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let subheadline = Font.system(size: 12, weight: .regular)
        static let footnote = Font.system(size: 11, weight: .regular)
        static let caption = Font.system(size: 10, weight: .regular)
        static let sectionHeader = Font.system(size: 11, weight: .semibold)
    }
}

// MARK: - Spacing

enum MRSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Radius

enum MRRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - Layout

enum MRLayout {
    static let gutter: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 12
    static let itemSpacing: CGFloat = 8
}

// MARK: - Animations

extension Animation {
    static let mrSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let mrQuick = Animation.spring(response: 0.25, dampingFraction: 0.85)
    static let mrFade = Animation.easeInOut(duration: 0.2)
}

// MARK: - View Modifiers

extension View {
    func mrCard(padding: CGFloat = MRLayout.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Color.MR.surface)
            .clipShape(RoundedRectangle(cornerRadius: MRLayout.cardRadius, style: .continuous))
            .mrShadowCard()
    }

    func mrSurface(padding: CGFloat = MRLayout.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Color.MR.surface)
            .clipShape(RoundedRectangle(cornerRadius: MRLayout.cardRadius, style: .continuous))
    }

    func mrShadowCard() -> some View {
        self.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    func mrShadowElevated() -> some View {
        self.shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
    }

    func mrSectionHeader() -> some View {
        self
            .font(Font.MR.sectionHeader)
            .foregroundColor(Color.MR.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
