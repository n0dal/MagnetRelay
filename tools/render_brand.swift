// Renders MagnetRelay brand art with AppKit/CoreGraphics.
//
//   swift tools/render_brand.swift <repo-root>
//   swift tools/render_brand.swift --appstore <repo-root>
//
// Writes:
//   MagnetRelay/Assets.xcassets/AppIcon.appiconset/icon_*.png   (16…1024 px, existing filenames)
//   assets/readme/hero-light.png, assets/readme/hero-dark.png  (1600×560)
//   assets/brand/magnetrelay-mark.svg                          (reference copy of the icon)
// With --appstore, only:
//   assets/appstore/screenshot_1280x800.png, screenshot_1440x900.png (Ready window on the background)
//
// This drawing code is the source of truth; the SVG is a reference copy. The glyph geometry
// matches MagnetRelay/Design/MagnetMark.swift (24×24 design space, U "M6 4v8a6 6 0 0 0 12 0V4",
// tips "M6 4h3M15 4h3", stroke 2.6, round caps, glyph box 58% of the tile).
// The hero and App Store images need Tests/screenshots/ready.png (and ready_dark.png for the hero),
// from Tests/visual_tests.sh.

import AppKit
import SwiftUI

// MARK: - Palette (Theme.swift / spec §3)

func hex(_ value: String, _ alpha: CGFloat = 1) -> CGColor {
    var int: UInt64 = 0
    Scanner(string: value).scanHexInt64(&int)
    return CGColor(srgbRed: CGFloat((int >> 16) & 0xFF) / 255,
                   green: CGFloat((int >> 8) & 0xFF) / 255,
                   blue: CGFloat(int & 0xFF) / 255,
                   alpha: alpha)
}

struct Palette {
    let background: CGColor
    let ink: CGColor
    let secondary: CGColor
    let hairline: CGColor
    let accent: CGColor

    static let light = Palette(background: hex("F6F5F3"), ink: hex("1D1D1F"), secondary: hex("6E6E73"),
                               hairline: CGColor(gray: 0, alpha: 0.09), accent: hex("E5484D"))
    static let dark = Palette(background: hex("1C1C1E"), ink: hex("F5F5F7"), secondary: hex("98989D"),
                              hairline: CGColor(gray: 1, alpha: 0.10), accent: hex("FF6369"))
}

let tileColor = hex("1D1D1F")
let tipColor = hex("E5484D")
let glyphFraction: CGFloat = 0.58
let designStroke: CGFloat = 2.6

// MARK: - Canvas

/// A top-left-origin sRGB bitmap context of the given pixel size.
func makeContext(width: Int, height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    return ctx
}

func writePNG(_ ctx: CGContext, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
    print("wrote \(url.path) (\(ctx.width)×\(ctx.height))")
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("missing image: \(url.path) — run Tests/visual_tests.sh to capture the Ready screen")
    }
    return image
}

/// Continuous-corner rounded rect, the same curve SwiftUI uses for `.continuous`.
func continuousRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
}

// MARK: - Mark

/// Maps the 24×24 design space onto `box` (a square), y down.
func designTransform(_ box: CGRect) -> CGAffineTransform {
    let scale = box.width / 24
    return CGAffineTransform(translationX: box.minX, y: box.minY).scaledBy(x: scale, y: scale)
}

func uPath(_ box: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 6, y: 4))
    path.addLine(to: CGPoint(x: 6, y: 12))
    path.addArc(tangent1End: CGPoint(x: 6, y: 18), tangent2End: CGPoint(x: 12, y: 18), radius: 6)
    path.addArc(tangent1End: CGPoint(x: 18, y: 18), tangent2End: CGPoint(x: 18, y: 12), radius: 6)
    path.addLine(to: CGPoint(x: 18, y: 4))
    var t = designTransform(box)
    return path.copy(using: &t)!
}

func tipsPath(_ box: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 6, y: 4))
    path.addLine(to: CGPoint(x: 9, y: 4))
    path.move(to: CGPoint(x: 15, y: 4))
    path.addLine(to: CGPoint(x: 18, y: 4))
    var t = designTransform(box)
    return path.copy(using: &t)!
}

/// Draws the white U with red tips inside the square `box`. `stroke` is in design units.
func drawGlyph(_ ctx: CGContext, box: CGRect, stroke: CGFloat) {
    let width = stroke * box.width / 24
    ctx.saveGState()
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(uPath(box))
    ctx.setStrokeColor(.white)
    ctx.strokePath()
    ctx.addPath(tipsPath(box))
    ctx.setStrokeColor(tipColor)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Dark tile + glyph. `highlight` adds the 1px inner top highlight (8% white).
/// `glyph` replaces the vector glyph (used for the grid-fitted small icon sizes).
func drawMark(_ ctx: CGContext, tile: CGRect, radius: CGFloat, highlight: CGFloat? = nil,
              border: CGColor? = nil, glyph: ((CGContext) -> Void)? = nil) {
    let tilePath = continuousRect(tile, radius: radius)
    ctx.addPath(tilePath)
    ctx.setFillColor(tileColor)
    ctx.fillPath()

    if let px = highlight {
        // A crescent along the top edge: the tile minus the tile shifted down by 1px.
        ctx.saveGState()
        ctx.addPath(tilePath)
        ctx.clip()
        ctx.addPath(tilePath)
        var down = CGAffineTransform(translationX: 0, y: px)
        ctx.addPath(tilePath.copy(using: &down)!)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.08))
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }
    if let border {
        ctx.saveGState()
        ctx.addPath(continuousRect(tile.insetBy(dx: 0.5, dy: 0.5), radius: radius - 0.5))
        ctx.setStrokeColor(border)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    if let glyph {
        glyph(ctx)
        return
    }
    let side = tile.width * glyphFraction
    let box = CGRect(x: tile.midX - side / 2, y: tile.midY - side / 2, width: side, height: side)
    drawGlyph(ctx, box: box, stroke: designStroke)
}

// MARK: - App icon

/// At 32px the vector glyph lands between pixels and blurs, so it is grid-fitted: a 2px stroke on
/// whole-pixel boundaries, legs 8px apart (10px ink width, about the design's 2.6/14.6 stroke ratio).
func drawGlyph32(_ ctx: CGContext) {
    let side: CGFloat = 16            // 12 design units between the legs = 8px
    let box = CGRect(x: 12 - side / 4, y: 11 - side / 6, width: side, height: side)  // legs x 12/20, tips y 11
    drawGlyph(ctx, box: box, stroke: 2 * 24 / side)
}

/// At 16px there is no room for round caps or a gap between vector tips, so the glyph is drawn as
/// pixels: a 6×6 U (1px stroke, about the design's stroke ratio) with 2px red tips on each leg.
func drawGlyph16(_ ctx: CGContext) {
    func px(_ x: Int, _ y: Int, _ color: CGColor, _ alpha: CGFloat = 1) {
        ctx.setFillColor(color.copy(alpha: alpha)!)
        ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
    }
    for x in [5, 6, 9, 10] { px(x, 5, tipColor) }               // pole tips
    for y in 6...9 { px(5, y, .white); px(10, y, .white) }      // legs
    for x in 6...9 { px(x, 10, .white) }                        // bottom of the U
    px(5, 10, .white, 0.4); px(10, 10, .white, 0.4)             // rounded outer corners
    px(6, 9, .white, 0.25); px(9, 9, .white, 0.25)              // soften the inner corners
}

func renderIcon(pixels: Int) -> CGContext {
    let ctx = makeContext(width: pixels, height: pixels)
    let s = CGFloat(pixels) / 1024
    let tile = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    switch pixels {
    case 16:
        drawMark(ctx, tile: tile, radius: 185 * s, glyph: drawGlyph16)
    case 32:
        drawMark(ctx, tile: tile, radius: 185 * s, glyph: drawGlyph32)
    default:
        // The highlight is 1px at 1024 and scales with the icon.
        drawMark(ctx, tile: tile, radius: 185 * s, highlight: max(1, s))
    }
    return ctx
}

// MARK: - Window screenshot

/// Draws a window capture clipped to a 12px continuous radius, with one soft shadow and a hairline.
func drawWindowShot(_ ctx: CGContext, _ screenshot: CGImage, in shot: CGRect, palette: Palette, dark: Bool) {
    let windowRadius: CGFloat = 12
    let windowPath = continuousRect(shot, radius: windowRadius)

    // One soft shadow under the window.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 44,
                  color: CGColor(gray: 0, alpha: dark ? 0.45 : 0.13))
    ctx.addPath(windowPath)
    ctx.setFillColor(palette.background)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(windowPath)
    ctx.clip()
    // The context is flipped; draw the image upright.
    ctx.translateBy(x: 0, y: shot.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(screenshot, in: CGRect(x: shot.minX, y: 0, width: shot.width, height: shot.height))
    ctx.restoreGState()

    // Hairline around the window.
    ctx.saveGState()
    ctx.addPath(continuousRect(shot.insetBy(dx: 0.5, dy: 0.5), radius: windowRadius - 0.5))
    ctx.setStrokeColor(dark ? CGColor(gray: 1, alpha: 0.14) : CGColor(gray: 0, alpha: 0.12))
    ctx.setLineWidth(1)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Hero

func drawText(_ ctx: CGContext, _ string: String, at origin: CGPoint, font: NSFont, color: CGColor,
              kern: CGFloat = 0) -> CGSize {
    let attributed = NSAttributedString(string: string, attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: color)!,
        .kern: kern,
    ])
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    attributed.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
    return attributed.size()
}

func renderHero(palette: Palette, screenshot: CGImage, dark: Bool) -> CGContext {
    let size = CGSize(width: 1600, height: 560)
    let ctx = makeContext(width: Int(size.width), height: Int(size.height))
    ctx.setFillColor(palette.background)
    ctx.fill(CGRect(origin: .zero, size: size))

    // Right: the Ready window, scaled so it sits with a 56px margin top and bottom.
    let margin: CGFloat = 56
    let shotHeight = size.height - margin * 2
    let shotWidth = shotHeight * CGFloat(screenshot.width) / CGFloat(screenshot.height)
    let shot = CGRect(x: size.width - 112 - shotWidth, y: margin, width: shotWidth, height: shotHeight)
    drawWindowShot(ctx, screenshot, in: shot, palette: palette, dark: dark)

    // Left: mark, name, pitch — a block vertically centred on the canvas.
    let left: CGFloat = 112
    let markSize: CGFloat = 120
    let titleFont = NSFont.systemFont(ofSize: 64, weight: .semibold)
    let pitchFont = NSFont.systemFont(ofSize: 24, weight: .regular)
    let titleHeight = ceil(titleFont.ascender - titleFont.descender)
    let pitchHeight = ceil(pitchFont.ascender - pitchFont.descender)
    let gapMarkTitle: CGFloat = 36
    let gapTitlePitch: CGFloat = 10
    let blockHeight = markSize + gapMarkTitle + titleHeight + gapTitlePitch + pitchHeight
    var y = ((size.height - blockHeight) / 2).rounded()

    drawMark(ctx, tile: CGRect(x: left, y: y, width: markSize, height: markSize), radius: markSize * 0.24,
             border: dark ? palette.hairline : nil)
    y += markSize + gapMarkTitle
    // Optical alignment: SF's side bearing at 64pt sits ~4px in from the box edge.
    _ = drawText(ctx, "MagnetRelay", at: CGPoint(x: left - 3, y: y), font: titleFont, color: palette.ink,
                 kern: -0.02 * 64)
    y += titleHeight + gapTitlePitch
    _ = drawText(ctx, "Click a magnet link. It lands on your home server.", at: CGPoint(x: left - 1, y: y),
                 font: pitchFont, color: palette.secondary)
    return ctx
}

// MARK: - App Store

/// The window centred on the light background, its height 78% of the canvas (rounded to whole pixels).
func renderAppStore(width: Int, height: Int, screenshot: CGImage) -> CGContext {
    let ctx = makeContext(width: width, height: height)
    ctx.setFillColor(Palette.light.background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let shotHeight = (CGFloat(height) * 0.78).rounded()
    let shotWidth = (shotHeight * CGFloat(screenshot.width) / CGFloat(screenshot.height)).rounded()
    let shot = CGRect(x: ((CGFloat(width) - shotWidth) / 2).rounded(), y: ((CGFloat(height) - shotHeight) / 2).rounded(),
                      width: shotWidth, height: shotHeight)
    drawWindowShot(ctx, screenshot, in: shot, palette: .light, dark: false)
    return ctx
}

// MARK: - SVG reference

func iconSVG() -> String {
    // Same numbers as renderIcon at 1024. SVG has no continuous-corner primitive, so the tile is a
    // plain rounded rect here; the PNGs use the continuous curve.
    let side = 824 * glyphFraction
    let origin = 512 - side / 2
    let scale = side / 24
    func f(_ v: CGFloat) -> String { String(format: "%.3f", Double(v)) }
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      <!-- MagnetRelay app icon (reference copy; tools/render_brand.swift is the source of truth). -->
      <!-- macOS icon grid: 824×824 tile centred on a 1024 canvas, corner radius 185. -->
      <rect x="100" y="100" width="824" height="824" rx="185" ry="185" fill="#1D1D1F"/>
      <!-- Glyph: 24×24 design space scaled to 58% of the tile. -->
      <g transform="translate(\(f(origin)) \(f(origin))) scale(\(f(scale)))" fill="none" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">
        <path d="M6 4v8a6 6 0 0 0 12 0V4" stroke="#FFFFFF"/>
        <path d="M6 4h3M15 4h3" stroke="#E5484D"/>
      </g>
    </svg>

    """
}

// MARK: - Main

var args = Array(CommandLine.arguments.dropFirst())
let appStoreOnly = args.first == "--appstore"
if appStoreOnly { args.removeFirst() }
guard args.count == 1 else {
    FileHandle.standardError.write("usage: swift tools/render_brand.swift [--appstore] <repo-root>\n".data(using: .utf8)!)
    exit(2)
}
let root = URL(fileURLWithPath: args[0], isDirectory: true)
let shots = root.appendingPathComponent("Tests/screenshots", isDirectory: true)

if appStoreOnly {
    let appStoreDir = root.appendingPathComponent("assets/appstore", isDirectory: true)
    try! FileManager.default.createDirectory(at: appStoreDir, withIntermediateDirectories: true)
    let ready = loadImage(shots.appendingPathComponent("ready.png"))
    for (w, h) in [(1280, 800), (1440, 900)] {
        writePNG(renderAppStore(width: w, height: h, screenshot: ready),
                 to: appStoreDir.appendingPathComponent("screenshot_\(w)x\(h).png"))
    }
    exit(0)
}

let iconDir = root.appendingPathComponent("MagnetRelay/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let readmeDir = root.appendingPathComponent("assets/readme", isDirectory: true)
let brandDir = root.appendingPathComponent("assets/brand", isDirectory: true)
for dir in [readmeDir, brandDir] {
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in iconFiles {
    writePNG(renderIcon(pixels: pixels), to: iconDir.appendingPathComponent(name))
}

writePNG(renderHero(palette: .light, screenshot: loadImage(shots.appendingPathComponent("ready.png")), dark: false),
         to: readmeDir.appendingPathComponent("hero-light.png"))
writePNG(renderHero(palette: .dark, screenshot: loadImage(shots.appendingPathComponent("ready_dark.png")), dark: true),
         to: readmeDir.appendingPathComponent("hero-dark.png"))

let svgURL = brandDir.appendingPathComponent("magnetrelay-mark.svg")
try! iconSVG().write(to: svgURL, atomically: true, encoding: .utf8)
print("wrote \(svgURL.path)")
