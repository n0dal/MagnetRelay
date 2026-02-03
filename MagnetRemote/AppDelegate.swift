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

    /// Creates a horseshoe magnet icon for the menu bar
    private func createMagnetIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()

            // Magnet dimensions
            let magnetWidth: CGFloat = 12
            let magnetHeight: CGFloat = 14
            let armWidth: CGFloat = 3.5
            let cornerRadius: CGFloat = 2
            let topRadius: CGFloat = (magnetWidth - armWidth) / 2

            // Center the magnet in the icon
            let offsetX = (rect.width - magnetWidth) / 2
            let offsetY = (rect.height - magnetHeight) / 2 - 0.5

            // Left arm
            let leftArm = NSBezierPath(roundedRect: NSRect(
                x: offsetX,
                y: offsetY,
                width: armWidth,
                height: magnetHeight - topRadius
            ), xRadius: cornerRadius, yRadius: cornerRadius)
            path.append(leftArm)

            // Right arm
            let rightArm = NSBezierPath(roundedRect: NSRect(
                x: offsetX + magnetWidth - armWidth,
                y: offsetY,
                width: armWidth,
                height: magnetHeight - topRadius
            ), xRadius: cornerRadius, yRadius: cornerRadius)
            path.append(rightArm)

            // Top arc connecting the arms
            let arcPath = NSBezierPath()
            let arcCenter = NSPoint(x: rect.width / 2, y: offsetY + magnetHeight - topRadius)
            let outerRadius = magnetWidth / 2
            let innerRadius = outerRadius - armWidth

            // Outer arc (top of magnet)
            arcPath.appendArc(
                withCenter: arcCenter,
                radius: outerRadius,
                startAngle: 0,
                endAngle: 180,
                clockwise: false
            )

            // Inner arc (creates the horseshoe opening)
            arcPath.appendArc(
                withCenter: arcCenter,
                radius: innerRadius,
                startAngle: 180,
                endAngle: 0,
                clockwise: true
            )

            arcPath.close()
            path.append(arcPath)

            // Fill the path
            NSColor.black.setFill()
            path.fill()

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
