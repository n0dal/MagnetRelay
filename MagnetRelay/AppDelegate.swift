import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var magnetHandler: MagnetHandler!
    private let notifier = Notifier()
    private var settingsWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // URL handler MUST be registered early to catch URLs on cold launch
        setupURLHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The hosted XCTest runner must not do first-launch UI at startup.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        UNUserNotificationCenter.current().delegate = notifier
        setupEditMenu()
        setupStatusBar()
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
            button.image = MagnetMarkImage.menuBarImage()  // Template: adapts to menu bar appearance
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
            let headerItem = NSMenuItem(title: "Recent Links", action: nil, keyEquivalent: "")
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

            menu.addItem(NSMenuItem.separator())
        }

        // Standard menu items
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MagnetRelay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func resendMagnet(_ sender: NSMenuItem) {
        guard let magnetURL = sender.representedObject as? String else { return }
        resend(magnetURL)
    }

    private func resend(_ magnetURL: String) {
        Task {
            await magnetHandler.handleMagnet(magnetURL)
        }
    }

    private func setupURLHandler() {
        magnetHandler = MagnetHandler(notifier: notifier, openSettings: { [weak self] in self?.openSettings() })

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

    /// Add a hidden Edit menu so standard keyboard shortcuts (Cmd+C/V/X/A) work in text fields.
    /// `.commandsRemoved()` in the SwiftUI scene strips all menus including Edit.
    private func setupEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu()
        }
        NSApp.mainMenu?.addItem(editMenuItem)
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

        let settingsView = SettingsRootView(resend: { [weak self] in self?.resend($0) })
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "MagnetRelay"
        window.styleMask = [.titled, .closable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self

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

    // MARK: - NSWindowDelegate

    /// Tear the content down on close so the next open starts fresh (Ready, or step 1 on first run)
    /// and any in-flight connection test is cancelled.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        window.contentViewController = nil
        // Free the autosave name (the frame is already saved) so the next window can claim it.
        window.setFrameAutosaveName("")
        settingsWindow = nil
    }
}
