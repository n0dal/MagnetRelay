import AppKit
import SwiftUI

/// Which of the settings window's two screens is showing.
enum SettingsScreen: Equatable {
    case ready
    case setup

    /// Clicking away (the app resigning active) closes the panel only on Ready. During the
    /// setup steps it stays open until they finish or the user presses Esc.
    var closesWhenAppDeactivates: Bool { self == .ready }
}

/// The settings window: a borderless floating panel (no title bar, no window buttons),
/// Spotlight style. The rounded warm-grey surface and hairline edge are drawn by the SwiftUI
/// content; the panel itself is transparent and carries the system shadow.
/// Esc and ⌘W close it; it can become key so text fields take focus.
final class SettingsPanel: NSPanel {
    init(contentViewController: NSViewController) {
        super.init(contentRect: NSRect(origin: .zero, size: RelayMetrics.windowSize),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        self.contentViewController = contentViewController
        setContentSize(RelayMetrics.windowSize)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        hidesOnDeactivate = false
        isFloatingPanel = false
        isReleasedWhenClosed = false
        isMovable = true
        collectionBehavior = [.moveToActiveSpace, .participatesInCycle]
        setAccessibilityTitle("MagnetRelay")
    }

    // A borderless window can't become key or main by default; text fields need it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc (when nothing more specific handles it, e.g. an open completion list).
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }

    /// A borderless window has no close button, so the default `performClose` would only beep.
    /// Close directly, still asking the delegate first.
    override func performClose(_ sender: Any?) {
        if let delegate, delegate.windowShouldClose?(self) == false { return }
        close()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(performClose(_:)) { return true }
        return super.validateMenuItem(menuItem)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(performClose(_:)) { return true }
        return super.validateUserInterfaceItem(item)
    }

    /// Esc always closes, even while a text field is being edited (the field editor would
    /// otherwise turn Esc into "complete"). Text input composition (marked text) keeps its Esc.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, SettingsPanel.isPlainEscape(event),
           !((firstResponder as? NSTextView)?.hasMarkedText() ?? false) {
            performClose(nil)
            return
        }
        super.sendEvent(event)
    }

    static func isPlainEscape(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return event.keyCode == 53 && mods.isEmpty
    }

    /// The shadow follows the content's alpha; recompute it once the rounded surface is drawn.
    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in self?.invalidateShadow() }
    }
}

// MARK: - SwiftUI pieces

/// The quiet "esc" hint in the panel's top-right corner. Decorative: VoiceOver gets a Close action.
struct EscHint: View {
    var body: some View {
        Text("esc")
            .font(.system(size: 10.5))
            .foregroundStyle(Color.Relay.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth)
            )
            .accessibilityHidden(true)
    }
}

/// Lets the panel be dragged by its background: sits behind the content and starts a window
/// drag on mouse-down wherever nothing in front takes the click.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
