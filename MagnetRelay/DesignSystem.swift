import SwiftUI

// MARK: - Color Tokens

extension Color {
    enum MR {
        // Accent colors - Indigo/Purple to match app icon
        static let accent = Color(light: .init(hex: "6366F1"),  // Indigo
                                  dark: .init(hex: "818CF8"))   // Lighter indigo for dark mode
        static let accentMuted = Color(light: .init(hex: "6366F1", alpha: 0.12),
                                       dark: .init(hex: "818CF8", alpha: 0.20))

        // Secondary accent - Magnet red (for destructive actions or highlights)
        static let accentRed = Color(light: .init(hex: "EF4444"),
                                     dark: .init(hex: "F87171"))

        // Tertiary accent - Magnet blue (for info or secondary highlights)
        static let accentBlue = Color(light: .init(hex: "3B82F6"),
                                      dark: .init(hex: "60A5FA"))

        // Backgrounds - Subtle purple tint
        static let background = Color(light: .init(hex: "F8F8FC"),
                                      dark: .init(hex: "0F0F14"))
        static let surface = Color(light: .init(hex: "FFFFFF"),
                                   dark: .init(hex: "1A1A24"))
        static let surfaceElevated = Color(light: .init(hex: "FFFFFF"),
                                           dark: .init(hex: "24243A"))

        // Input fields - noticeably elevated from background for clarity
        static let inputBackground = Color(light: .init(hex: "FFFFFF"),
                                           dark: .init(hex: "1C1C28"))
        static let inputBackgroundFocused = Color(light: .init(hex: "FAFAFF"),
                                                  dark: .init(hex: "222232"))

        // Text hierarchy
        static let textPrimary = Color(light: .init(hex: "1A1A2E"),
                                       dark: .init(hex: "F0F0F8"))
        static let textSecondary = Color(light: .init(hex: "555570"),
                                         dark: .init(hex: "A0A0B8"))
        static let textTertiary = Color(light: .init(hex: "8888A0"),
                                        dark: .init(hex: "686880"))

        // Dividers & borders - Purple tinted
        static let divider = Color(light: .init(hex: "E8E8F0"),
                                   dark: .init(hex: "32324A"))
        static let border = Color(light: .init(hex: "D0D0E0"),
                                  dark: .init(hex: "44445C"))

        // Semantic colors
        static let success = Color(light: .init(hex: "22C55E"),
                                   dark: .init(hex: "4ADE80"))
        static let error = Color(light: .init(hex: "EF4444"),
                                 dark: .init(hex: "F87171"))
        static let warning = Color(light: .init(hex: "F59E0B"),
                                   dark: .init(hex: "FBBF24"))
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
