import SwiftUI

/// The settings panel's content: the three setup steps when setup hasn't completed (or while
/// changing the server), the Ready screen otherwise. See spec section 4.
struct SettingsRootView: View {
    @ObservedObject var config: ServerConfig = .shared
    /// Sends a recent link again through the app's magnet handler.
    let resend: (String) -> Void
    /// Closes the panel (VoiceOver's Close and escape actions).
    var close: () -> Void = {}
    /// Told which screen is showing, so the panel knows whether clicking away closes it.
    var onScreenChange: (SettingsScreen) -> Void = { _ in }

    /// Non-nil while the setup steps are on screen.
    @State private var flow: SetupFlowModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let flow {
                SetupFlowView(model: flow)
                    .transition(.opacity)
            } else {
                ReadyView(config: config, resend: resend, changeServer: { startFlow(.changeServer) })
                    .transition(.opacity)
            }
        }
        .frame(width: RelayMetrics.windowSize.width, height: RelayMetrics.windowSize.height)
        .overlay(alignment: .topTrailing) {
            EscHint().padding(.top, 12).padding(.trailing, 14).allowsHitTesting(false)
        }
        .background(WindowDragArea())
        .background(Color.Relay.background)
        .clipShape(panelShape)
        .overlay(panelShape.strokeBorder(Color.Relay.hairline, lineWidth: RelayMetrics.hairlineWidth).allowsHitTesting(false))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: flow == nil)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, close)
        .accessibilityAction(named: "Close", close)
        .onChange(of: flow == nil) { isReady in onScreenChange(isReady ? .ready : .setup) }
        // A fresh model each time the window opens: closing mid-"Change server" drops the draft.
        .onAppear {
            if config.hasCompletedSetup {
                flow = nil
            } else {
                startFlow(.firstRun)
            }
            onScreenChange(config.hasCompletedSetup ? .ready : .setup)
        }
        .onDisappear {
            flow?.cancelConnect()
            flow = nil
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RelayMetrics.panelCornerRadius, style: .continuous)
    }

    private func startFlow(_ mode: SetupFlowModel.Mode) {
        let model = SetupFlowModel(mode: mode, config: config, clientFactory: { BackendFactory.create(for: $0) })
        model.onFinish = { _ in
            // Connected: setup is now complete. Cancelled (change server, step 1): back to Ready.
            flow = nil
        }
        flow = model
    }
}
