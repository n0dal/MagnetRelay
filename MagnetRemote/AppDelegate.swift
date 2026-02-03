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
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Magnet Remote")
            button.image?.isTemplate = true  // Adapts to menu bar light/dark mode
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Magnet Remote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
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
        window.title = "Magnet Remote"
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
