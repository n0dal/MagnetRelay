import SwiftUI
import AppKit

// The mark is drawn from the reference SVG (24×24 viewBox):
//   <path d="M6 4v8a6 6 0 0 0 12 0V4"/>   the U, white
//   <path d="M6 4h3M15 4h3"/>              the pole tips, accent red
// Both shapes map that 24×24 design space onto the largest centred square in `rect`.

private func designTransform(for rect: CGRect) -> CGAffineTransform {
    let scale = min(rect.width, rect.height) / 24
    let originX = rect.midX - 12 * scale
    let originY = rect.midY - 12 * scale
    return CGAffineTransform(translationX: originX, y: originY).scaledBy(x: scale, y: scale)
}

/// The horseshoe: two legs from y=4 down to y=12, joined by a half circle of radius 6 centred at (12, 12).
struct MagnetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6, y: 4))
        path.addLine(to: CGPoint(x: 6, y: 12))
        // Two quarter arcs through the bottom of the U (tangent form avoids clockwise ambiguity in flipped space).
        path.addArc(tangent1End: CGPoint(x: 6, y: 18), tangent2End: CGPoint(x: 12, y: 18), radius: 6)
        path.addArc(tangent1End: CGPoint(x: 18, y: 18), tangent2End: CGPoint(x: 18, y: 12), radius: 6)
        path.addLine(to: CGPoint(x: 18, y: 4))
        return path.applying(designTransform(for: rect))
    }
}

/// The two pole tips: short horizontal strokes on top of each leg.
struct PoleTipsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6, y: 4))
        path.addLine(to: CGPoint(x: 9, y: 4))
        path.move(to: CGPoint(x: 15, y: 4))
        path.addLine(to: CGPoint(x: 18, y: 4))
        return path.applying(designTransform(for: rect))
    }
}

/// The app mark: a dark tile (same in light and dark mode) holding a white magnet with red pole tips.
/// Used at 30pt in the setup header and 56pt on the Ready screen.
struct MagnetMark: View {
    var size: CGFloat

    /// The tile colour is fixed: the mark looks the same in both appearances.
    static let tileColor = Color(nsColor: NSColor(hex: "1D1D1F"))
    /// Share of the tile the 24×24 glyph box occupies (17/30 and 32/56 in the mockup).
    static let glyphFraction: CGFloat = 0.58

    var body: some View {
        let glyph = size * Self.glyphFraction
        let style = StrokeStyle(lineWidth: size * 2.6 / 24 * Self.glyphFraction, lineCap: .round, lineJoin: .round)
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Self.tileColor)
            ZStack {
                MagnetShape().stroke(Color.white, style: style)
                PoleTipsShape().stroke(Color.Relay.accent, style: style)
            }
            .frame(width: glyph, height: glyph)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Monochrome template image of the magnet for the menu bar (no tile, no red).
enum MagnetMarkImage {
    static func menuBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // The glyph's inked area spans roughly x 4.7…19.3, y 2.7…19.3 in design units, so map
            // the design space at 1pt per unit offset by (3, 2): the magnet fills the 18pt canvas.
            let designRect = CGRect(x: -3, y: -2, width: 24, height: 24)
            var path = MagnetShape().path(in: designRect)
            path.addPath(PoleTipsShape().path(in: designRect))
            context.addPath(path.cgPath)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MagnetRelay"
        return image
    }
}

#Preview("MagnetMark") {
    HStack(spacing: 0) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            HStack(spacing: 20) {
                MagnetMark(size: 30)
                MagnetMark(size: 56)
                Image(nsImage: MagnetMarkImage.menuBarImage())
                    .foregroundStyle(Color.Relay.ink)
            }
            .padding(24)
            .background(Color.Relay.background)
            .environment(\.colorScheme, scheme)
        }
    }
}
