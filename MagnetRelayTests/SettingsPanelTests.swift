import XCTest
import AppKit
@testable import MagnetRelay

private final class CloseRecorder: NSObject, NSWindowDelegate {
    var allowsClose = true
    var closes = 0
    func windowShouldClose(_ sender: NSWindow) -> Bool { allowsClose }
    func windowWillClose(_ notification: Notification) { closes += 1 }
}

/// Stands in for the Recent links popover window: records the Esc it is handed and closes.
private final class ChildWindow: NSWindow {
    var escapes = 0
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 { escapes += 1; orderOut(nil); return }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) { escapes += 1; orderOut(nil) }
}

/// A child window that ignores Esc entirely (think tooltip or a third-party popover).
private final class DeafChildWindow: NSWindow {
    var escapes = 0
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 { escapes += 1; return }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) { escapes += 1 }
}

@MainActor
final class SettingsPanelTests: XCTestCase {
    private var panel: SettingsPanel!
    private var recorder: CloseRecorder!

    override func setUp() {
        panel = SettingsPanel(contentViewController: NSViewController(nibName: nil, bundle: nil))
        panel.contentViewController?.view = NSView(frame: NSRect(origin: .zero, size: RelayMetrics.windowSize))
        recorder = CloseRecorder()
        panel.delegate = recorder
        panel.orderFront(nil)
    }

    override func tearDown() {
        panel.delegate = nil
        panel.orderOut(nil)
        panel = nil
    }

    private func key(_ chars: String, code: UInt16, mods: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: mods, timestamp: 0,
                         windowNumber: panel.windowNumber, context: nil, characters: chars,
                         charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
    }

    // MARK: Click-away policy

    func testClickAwayClosesOnlyOnReady() {
        XCTAssertTrue(SettingsScreen.ready.closesWhenAppDeactivates)
        XCTAssertFalse(SettingsScreen.setup.closesWhenAppDeactivates)
    }

    // MARK: Panel setup

    func testIsBorderlessNormalLevelAndCanBecomeKey() {
        XCTAssertEqual(panel.styleMask, [.borderless])
        XCTAssertFalse(panel.styleMask.contains(.titled))
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
        XCTAssertEqual(panel.level, .normal)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.isFloatingPanel)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertFalse(panel.isReleasedWhenClosed)
        XCTAssertEqual(panel.frame.size, RelayMetrics.windowSize)
    }

    // MARK: Closing

    func testPerformCloseClosesDespiteNoCloseButton() {
        panel.performClose(nil)
        XCTAssertEqual(recorder.closes, 1)
        XCTAssertFalse(panel.isVisible)
    }

    func testPerformCloseRespectsWindowShouldClose() {
        recorder.allowsClose = false
        panel.performClose(nil)
        XCTAssertEqual(recorder.closes, 0)
        XCTAssertTrue(panel.isVisible)
    }

    func testCancelOperationCloses() {
        panel.cancelOperation(nil)
        XCTAssertEqual(recorder.closes, 1)
    }

    func testEscapeKeyCloses() {
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(recorder.closes, 1)
    }

    func testEscapeWithModifierOrOtherKeysDoNotClose() {
        XCTAssertFalse(SettingsPanel.isPlainEscape(key("\u{1b}", code: 53, mods: .shift)))
        XCTAssertFalse(SettingsPanel.isPlainEscape(key("a", code: 0)))
        XCTAssertTrue(SettingsPanel.isPlainEscape(key("\u{1b}", code: 53)))
        panel.sendEvent(key("a", code: 0))
        XCTAssertEqual(recorder.closes, 0)
    }

    func testCloseMenuItemIsEnabled() {
        let item = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        XCTAssertTrue(panel.validateMenuItem(item))
    }

    func testCommandWClosesThroughMenu() {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        item.target = panel
        XCTAssertTrue(menu.performKeyEquivalent(with: key("w", code: 13, mods: .command)))
        XCTAssertEqual(recorder.closes, 1)
    }

    // MARK: Child windows (Recent links popover)

    private func addChild() -> ChildWindow {
        let child = ChildWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
                                styleMask: [.borderless], backing: .buffered, defer: false)
        child.isReleasedWhenClosed = false
        panel.addChildWindow(child, ordered: .above)
        child.orderFront(nil)
        return child
    }

    func testEscapeDismissesOpenChildWindowNotThePanel() {
        let child = addChild()
        defer { panel.removeChildWindow(child); child.orderOut(nil) }
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(child.escapes, 1)
        XCTAssertFalse(child.isVisible)
        XCTAssertEqual(recorder.closes, 0)
        XCTAssertTrue(panel.isVisible)

        // With the child gone, the next Esc closes the panel.
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(recorder.closes, 1)
    }

    func testCancelOperationGoesToOpenChildWindow() {
        let child = addChild()
        defer { panel.removeChildWindow(child); child.orderOut(nil) }
        panel.cancelOperation(nil)
        XCTAssertEqual(child.escapes, 1)
        XCTAssertEqual(recorder.closes, 0)
    }

    private func addDeafChild() -> DeafChildWindow {
        let child = DeafChildWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
                                    styleMask: [.borderless], backing: .buffered, defer: false)
        child.isReleasedWhenClosed = false
        panel.addChildWindow(child, ordered: .above)
        child.orderFront(nil)
        return child
    }

    func testEscapeNeverGoesDeadWhenChildIgnoresIt() {
        let child = addDeafChild()
        defer { panel.removeChildWindow(child); child.orderOut(nil) }
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(child.escapes, 1)
        XCTAssertEqual(recorder.closes, 0)
        XCTAssertTrue(child.isVisible)

        // The child ignored it, so the second Esc closes the panel.
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(child.escapes, 1)
        XCTAssertEqual(recorder.closes, 1)
    }

    func testCancelOperationNeverGoesDeadWhenChildIgnoresIt() {
        let child = addDeafChild()
        defer { panel.removeChildWindow(child); child.orderOut(nil) }
        panel.cancelOperation(nil)
        XCTAssertEqual(recorder.closes, 0)
        panel.cancelOperation(nil)
        XCTAssertEqual(recorder.closes, 1)
    }

    func testOtherInputGivesTheChildAnotherEscape() {
        let child = addDeafChild()
        defer { panel.removeChildWindow(child); child.orderOut(nil) }
        panel.sendEvent(key("\u{1b}", code: 53))
        panel.sendEvent(key("a", code: 0))      // e.g. reopening the popover from the keyboard
        panel.sendEvent(key("\u{1b}", code: 53))
        XCTAssertEqual(child.escapes, 2)
        XCTAssertEqual(recorder.closes, 0)
    }
}
