import SwiftUI
import AppKit

// In-process screenshot harness for the README panel shots (run via tools/screenshots/build.sh). Hosts the real SettingsRootView in a
// real SettingsPanel with throwaway configs (never com.magnetrelay.app defaults or the Keychain),
// snapshots with cacheDisplay at 2x, and writes:
//   <raw>/  ready.png, ready_dark.png, ...      raw panel (transparent corners), input to render_brand
//   <readme>/ client.png, address.png, ...      README shots: panel on a transparent canvas, soft shadow

final class MemPasswords: PasswordStoring {
    var stored: String?
    init(_ p: String? = nil) { stored = p }
    func password() -> String? { stored }
    func setPassword(_ p: String) -> Bool { stored = p; return true }
}

let rawDir = CommandLine.arguments[1]
let readmeDir = CommandLine.arguments[2]

func tempConfig(password: String? = nil) -> ServerConfig {
    ServerConfig(store: UserDefaults(suiteName: "shotsB-\(UUID().uuidString)")!, passwords: MemPasswords(password))
}

@MainActor func makePanel(_ view: SettingsRootView, dark: Bool) -> SettingsPanel {
    let p = SettingsPanel(contentViewController: NSHostingController(rootView: view))
    p.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    p.center()
    p.orderFrontRegardless(); p.makeKey()
    NSApp.activate(ignoringOtherApps: true)
    return p
}

func pause(_ s: Double = 0.6) async { try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) }

@MainActor func capture(_ w: NSWindow) -> NSBitmapImageRep {
    let frameView = w.contentView!.superview!
    frameView.layoutSubtreeIfNeeded(); frameView.display()
    let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds)!
    frameView.cacheDisplay(in: frameView.bounds, to: rep)
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("saved \(path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
}

/// A transparent 2x canvas of `size` points.
func canvas(_ size: NSSize) -> NSBitmapImageRep {
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    out.size = size
    return out
}

let shotMargin: CGFloat = 28

let popInset: CGFloat = 6

/// Draws `layers` (image, rect in canvas points, y up) onto a transparent canvas, each with one soft
/// shadow, then optionally a popover: a rounded surface (`bubble`) with the captured content on top.
func compose(_ size: NSSize, _ layers: [(NSBitmapImageRep, NSRect)],
             popover: (NSBitmapImageRep, NSRect, NSRect)? = nil, dark: Bool = false) -> NSBitmapImageRep {
    let out = canvas(size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current!.imageInterpolation = .high
    func softShadow(_ alpha: CGFloat, blur: CGFloat, y: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: alpha)
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = NSSize(width: 0, height: -y)
        shadow.set()
    }
    for (rep, rect) in layers {
        NSGraphicsContext.saveGraphicsState()
        softShadow(dark ? 0.35 : 0.16, blur: 22, y: 6)
        rep.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }
    if let (rep, rect, bubble) = popover {
        let path = NSBezierPath(roundedRect: bubble, xRadius: 14, yRadius: 14)
        NSGraphicsContext.saveGraphicsState()
        softShadow(dark ? 0.45 : 0.20, blur: 18, y: 5)
        (dark ? NSColor(srgbRed: 0.20, green: 0.20, blue: 0.21, alpha: 1) : NSColor(srgbRed: 0xF6/255.0, green: 0xF5/255.0, blue: 0xF3/255.0, alpha: 1)).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        (dark ? NSColor(white: 1, alpha: 0.12) : NSColor(white: 0, alpha: 0.10)).setStroke()
        let edge = NSBezierPath(roundedRect: bubble.insetBy(dx: 0.25, dy: 0.25), xRadius: 13.75, yRadius: 13.75)
        edge.lineWidth = 0.5
        edge.stroke()
        rep.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    NSGraphicsContext.restoreGraphicsState()
    return out
}

@MainActor func shoot(_ w: NSWindow, raw: String?, readme: String?) {
    let rep = capture(w)
    if let raw { save(rep, "\(rawDir)/\(raw).png") }
    if let readme {
        let s = rep.size
        let out = compose(NSSize(width: s.width + 2 * shotMargin, height: s.height + 2 * shotMargin),
                          [(rep, NSRect(x: shotMargin, y: shotMargin, width: s.width, height: s.height))])
        save(out, "\(readmeDir)/\(readme).png")
    }
}

@MainActor func key(_ w: NSWindow, _ chars: String, _ code: UInt16) {
    let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: w.windowNumber,
                             context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
    w.sendEvent(e)
}

let seedLinks: [(String, String)] = [
    ("ubuntu-24.04.1-desktop-amd64.iso", "3f19b149f53a50e14fc0b79926a391896eabab6f"),
    ("debian-12.8.0-amd64-netinst.iso", "6c0a7b8f1e3d2a49b5c7e9f0a1b2c3d4e5f60718"),
    ("Fedora-Workstation-Live-x86_64-41", "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"),
    ("archlinux-2024.11.01-x86_64.iso", "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c"),
    ("Big Buck Bunny (Blender open movie)", "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c"),
]

@MainActor func seedRecent() {
    RecentMagnets.shared.clear()
    for (name, hash) in seedLinks.reversed() {
        let dn = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._")))!
        RecentMagnets.shared.add("magnet:?xt=urn:btih:\(hash)&dn=\(dn)")
    }
}

@MainActor func readyConfig() -> ServerConfig {
    let c = tempConfig()
    c.clientType = .qbittorrent; c.serverHost = "192.168.0.100"; c.serverPort = "8080"
    c.hasCompletedSetup = true; c.markConfigAsTested()
    c.lastConnectedAt = Date().timeIntervalSince1970 - 120
    return c
}

@MainActor func popoverWindow(of panel: NSWindow) -> NSWindow? {
    NSApp.windows.first { $0 !== panel && $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
}

@MainActor func quickOpen(_ p: NSWindow) async -> NSWindow? {
    let pt = NSPoint(x: 60, y: p.frame.height - 367)
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        p.sendEvent(NSEvent.mouseEvent(with: type, location: pt, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                       windowNumber: p.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
    }
    await pause(0.08)
    return popoverWindow(of: p)
}

@MainActor func run() async {
    seedRecent()
    for dark in [false, true] {
        let sfx = dark ? "_dark" : ""
        let rsfx = dark ? "-dark" : ""

        // Ready
        let r = makePanel(SettingsRootView(config: readyConfig(), resend: { _ in }), dark: dark)
        await pause(); shoot(r, raw: "ready\(sfx)", readme: "ready\(rsfx)")

        // Recent links: Ready with the popover open, both windows composited at their screen positions.
        if let pop = await quickOpen(r) {
            // The popover's own glass background doesn't survive cacheDisplay, so its SwiftUI
            // content is captured alone and set on a drawn popover surface at the real position.
            let content = pop.contentView!
            let popRep = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
            content.cacheDisplay(in: content.bounds, to: popRep)
            let panelRep = capture(r)
            // Placed the way macOS places it when there is no room below: above "Recent links ›"
            // (button top 73pt above the panel's bottom edge, 6pt gap), its left edge 12pt in from
            // the panel's, so the canvas stays the panel's own and the footer stays readable.
            let size = NSSize(width: r.frame.width + 2 * shotMargin, height: r.frame.height + 2 * shotMargin)
            let panelRect = NSRect(x: shotMargin, y: shotMargin, width: r.frame.width, height: r.frame.height)
            func place(_ f: NSRect) -> NSRect { f == r.frame ? panelRect : f }
            let bubbleSize = NSSize(width: pop.frame.width - 2 * popInset, height: pop.frame.height - 2 * popInset)
            let bubble = NSRect(x: panelRect.minX + 12, y: panelRect.minY + 73 + 6, width: bubbleSize.width, height: bubbleSize.height)
            let popRect = bubble.insetBy(dx: -popInset, dy: -popInset)
            if !dark {
                save(compose(size, [(panelRep, place(r.frame))], popover: (popRep, popRect, bubble), dark: dark),
                     "\(readmeDir)/recent-links.png")
            }
            save(popRep, "\(rawDir)/popover\(sfx).png")
        } else { print("no popover window") }
        r.close(); await pause(0.3)

        // Setup: client, address, sign in, with real values so Continue / Connect are enabled.
        let c = tempConfig(password: "correct-horse")
        c.clientType = .qbittorrent; c.serverHost = "192.168.0.100"; c.serverPort = "8080"; c.username = "admin"
        let s = makePanel(SettingsRootView(config: c, resend: { _ in }), dark: dark)
        await pause(); s.makeFirstResponder(nil); shoot(s, raw: "client\(sfx)", readme: dark ? nil : "client")
        key(s, "\r", 36); await pause(); s.makeFirstResponder(nil); await pause(0.2)
        shoot(s, raw: "address\(sfx)", readme: dark ? nil : "address")
        key(s, "\r", 36); await pause(); s.makeFirstResponder(nil); await pause(0.2)
        shoot(s, raw: "signin\(sfx)", readme: dark ? nil : "signin")
        s.close(); await pause(0.3)
    }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
Task { @MainActor in await run() }
app.run()
