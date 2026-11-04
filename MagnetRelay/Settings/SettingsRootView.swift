import SwiftUI

/// The settings window's content: the three setup steps when setup hasn't completed (or while
/// changing the server), the Ready screen otherwise. See spec section 4.
struct SettingsRootView: View {
    @ObservedObject var config: ServerConfig = .shared
    /// Sends a recent link again through the app's magnet handler.
    let resend: (String) -> Void

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
        .frame(width: RelayMetrics.contentSize.width, height: RelayMetrics.contentSize.height)
        .background(Color.Relay.background)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: flow == nil)
        // A fresh model each time the window opens: closing mid-"Change server" drops the draft.
        .onAppear {
            if config.hasCompletedSetup {
                flow = nil
            } else {
                startFlow(.firstRun)
            }
        }
        .onDisappear {
            flow?.cancelConnect()
            flow = nil
        }
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
