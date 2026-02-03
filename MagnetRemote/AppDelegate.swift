import Cocoa
import SwiftUI
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var magnetHandler: MagnetHandler!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

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
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Recent magnets section
        let recentItems = RecentMagnets.shared.items
        if !recentItems.isEmpty {
            let headerItem = NSMenuItem(title: "Recent Magnets", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for item in recentItems.prefix(5) {
                let menuItem = NSMenuItem(
                    title: item.displayName,
                    action: #selector(resendMagnet(_:)),
                    keyEquivalent: ""
                )
                menuItem.representedObject = item.magnetURL
                menuItem.indentationLevel = 1
                menu.addItem(menuItem)
            }

            if recentItems.count > 5 {
                let moreItem = NSMenuItem(
                    title: "(\(recentItems.count - 5) more...)",
                    action: nil,
                    keyEquivalent: ""
                )
                moreItem.isEnabled = false
                moreItem.indentationLevel = 1
                menu.addItem(moreItem)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Standard menu items
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Magnet Remote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func resendMagnet(_ sender: NSMenuItem) {
        guard let magnetURL = sender.representedObject as? String else { return }
        Task {
            await magnetHandler.handleMagnet(magnetURL)
        }
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
