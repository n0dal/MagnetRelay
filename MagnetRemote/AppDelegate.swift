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

    /// Creates a clean horseshoe magnet icon for the menu bar
    private func createMagnetIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            // Simple, clean horseshoe magnet centered in the icon
            let magnetPath = NSBezierPath()

            // Dimensions for a clear, recognizable magnet
            let centerX = rect.width / 2
            let outerRadius: CGFloat = 7
            let innerRadius: CGFloat = 4
            let armLength: CGFloat = 5

            // Starting points for the arms
            let leftOuterX = centerX - outerRadius
            let rightOuterX = centerX + outerRadius
            let leftInnerX = centerX - innerRadius
            let rightInnerX = centerX + innerRadius
            let armBottom: CGFloat = 2
            let arcCenterY: CGFloat = armBottom + armLength

            // Draw outer shape: left arm up, arc over, right arm down
            magnetPath.move(to: NSPoint(x: leftOuterX, y: armBottom))
            magnetPath.line(to: NSPoint(x: leftOuterX, y: arcCenterY))
            magnetPath.appendArc(
                withCenter: NSPoint(x: centerX, y: arcCenterY),
                radius: outerRadius,
                startAngle: 180,
                endAngle: 0,
                clockwise: false
            )
            magnetPath.line(to: NSPoint(x: rightOuterX, y: armBottom))

            // Draw inner cutout: right inner up, arc back, left inner down
            magnetPath.line(to: NSPoint(x: rightInnerX, y: armBottom))
            magnetPath.line(to: NSPoint(x: rightInnerX, y: arcCenterY))
            magnetPath.appendArc(
                withCenter: NSPoint(x: centerX, y: arcCenterY),
                radius: innerRadius,
                startAngle: 0,
                endAngle: 180,
                clockwise: true
            )
            magnetPath.line(to: NSPoint(x: leftInnerX, y: armBottom))
            magnetPath.close()

            magnetPath.fill()

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
