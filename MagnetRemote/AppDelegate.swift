import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var magnetHandler: MagnetHandler!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupURLHandler()
        requestNotificationPermission()

        // Show settings on first launch
        if !ServerConfig.shared.hasCompletedSetup {
            DispatchQueue.main.async {
                self.openSettings()
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = createMagnetIcon()
            button.image?.isTemplate = true  // Adapts to menu bar light/dark mode
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Magnet Remote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    /// Creates a horseshoe magnet icon with signal waves for the menu bar
    private func createMagnetIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Magnet dimensions - shifted left to make room for signal
            let magnetWidth: CGFloat = 10
            let magnetHeight: CGFloat = 12
            let armWidth: CGFloat = 3.0
            let tipHeight: CGFloat = 2.0

            // Offset magnet to the left to make room for signal waves
            let offsetX: CGFloat = 1.5
            let offsetY: CGFloat = (rect.height - magnetHeight) / 2

            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Draw the horseshoe magnet body
            let magnetPath = NSBezierPath()

            // Left arm (bottom to top)
            let leftArmBottom = NSPoint(x: offsetX, y: offsetY + tipHeight)
            let leftArmTop = NSPoint(x: offsetX, y: offsetY + magnetHeight - magnetWidth/2)

            // Right arm (bottom to top)
            let rightArmBottom = NSPoint(x: offsetX + magnetWidth - armWidth, y: offsetY + tipHeight)
            let rightArmTop = NSPoint(x: offsetX + magnetWidth - armWidth, y: offsetY + magnetHeight - magnetWidth/2)

            // Start from bottom left, go up, arc over, come down
            magnetPath.move(to: leftArmBottom)
            magnetPath.line(to: leftArmTop)

            // Top arc
            let arcCenter = NSPoint(x: offsetX + magnetWidth/2, y: offsetY + magnetHeight - magnetWidth/2)
            magnetPath.appendArc(
                withCenter: arcCenter,
                radius: magnetWidth/2,
                startAngle: 180,
                endAngle: 0,
                clockwise: false
            )

            // Down the right side
            magnetPath.line(to: NSPoint(x: offsetX + magnetWidth, y: offsetY + tipHeight))

            // Inner right edge going up
            magnetPath.line(to: NSPoint(x: offsetX + magnetWidth - armWidth, y: offsetY + tipHeight))
            magnetPath.line(to: rightArmTop)

            // Inner arc
            magnetPath.appendArc(
                withCenter: arcCenter,
                radius: magnetWidth/2 - armWidth,
                startAngle: 0,
                endAngle: 180,
                clockwise: true
            )

            // Back down left inner edge
            magnetPath.line(to: NSPoint(x: offsetX + armWidth, y: offsetY + tipHeight))
            magnetPath.close()

            magnetPath.fill()

            // Draw pole tips (horizontal lines at bottom of each arm)
            let tipPath = NSBezierPath()

            // Left tip
            tipPath.move(to: NSPoint(x: offsetX - 0.5, y: offsetY + tipHeight))
            tipPath.line(to: NSPoint(x: offsetX + armWidth + 0.5, y: offsetY + tipHeight))

            // Right tip
            tipPath.move(to: NSPoint(x: offsetX + magnetWidth - armWidth - 0.5, y: offsetY + tipHeight))
            tipPath.line(to: NSPoint(x: offsetX + magnetWidth + 0.5, y: offsetY + tipHeight))

            tipPath.lineWidth = 1.5
            tipPath.lineCapStyle = .round
            tipPath.stroke()

            // Draw signal waves (indicating "remote" / sending)
            let signalX: CGFloat = offsetX + magnetWidth + 3
            let signalCenterY: CGFloat = rect.height / 2

            for i in 0..<3 {
                let waveRadius: CGFloat = 2.0 + CGFloat(i) * 2.5
                let wavePath = NSBezierPath()
                wavePath.appendArc(
                    withCenter: NSPoint(x: signalX, y: signalCenterY),
                    radius: waveRadius,
                    startAngle: -45,
                    endAngle: 45,
                    clockwise: false
                )
                wavePath.lineWidth = 1.2
                wavePath.lineCapStyle = .round
                wavePath.stroke()
            }

            return true
        }

        image.isTemplate = true
        return image
    }

    private func setupURLHandler() {
        magnetHandler = MagnetHandler()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

        Task {
            await magnetHandler.handleMagnet(urlString)
        }
    }

    @objc private func openSettings() {
        // Activate app first - critical for menu bar apps to bring windows to front
        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow {
            bringWindowToFront(window)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Magnet Remote Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        // Ensure window moves to current space and can become key
        window.collectionBehavior = [.moveToActiveSpace, .participatesInCycle]

        self.settingsWindow = window
        bringWindowToFront(window)
    }

    private func bringWindowToFront(_ window: NSWindow) {
        // orderFrontRegardless is more aggressive than makeKeyAndOrderFront
        window.orderFrontRegardless()
        window.makeKey()

        // Double-activate to ensure focus on menu bar apps
        NSApp.activate(ignoringOtherApps: true)
    }

}
