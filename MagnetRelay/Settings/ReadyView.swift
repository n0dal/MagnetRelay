import SwiftUI

/// Shown every time the window opens once setup is complete. See spec section 4.2.
struct ReadyView: View {
    @ObservedObject var config: ServerConfig
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
    let resend: (String) -> Void
    let changeServer: () -> Void

    @State private var showsRecent = false

    private static let privacyURL = URL(string: "https://github.com/n0dal/MagnetRelay/blob/main/PRIVACY.md")!
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                MagnetMark(size: 56)
                Text("You're all set.")
                    .relayHeading()
                    .padding(.top, 14)
                Text("Click any magnet link and it goes to your server.")
                    .font(Font.Relay.body)
                    .foregroundStyle(Color.Relay.secondary)
                    .padding(.top, 4)
                // Re-evaluated periodically so "checked 2 min ago" stays current while open.
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    StatusPill(isReady: config.isCurrentConfigTested, text: statusText)
                }
                .padding(.top, 14)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)

            RelayCard {
                RelayRow(title: "Open at login") {
                    RelaySwitch(title: "Open at login",
                                isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) }))
                }
                RelayRow(title: "Notify when a link is sent") {
                    RelaySwitch(title: "Notify when a link is sent", isOn: $config.showNotifications)
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 0)

            HStack {
                Button {
                    showsRecent.toggle()
                } label: {
                    Text("Recent links ›")
                        .font(Font.Relay.body)
                        .foregroundStyle(Color.Relay.ink)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recent links")
                .popover(isPresented: $showsRecent, arrowEdge: .bottom) {
                    RecentLinksView { url in
                        showsRecent = false
                        resend(url)
                    }
                }

                Spacer()

                Button("Change server", action: changeServer)
                    .buttonStyle(RelaySecondaryButtonStyle())
            }
            .padding(.top, 14)

            HStack(spacing: 4) {
                Link("Privacy Policy", destination: Self.privacyURL)
                if let version = Self.version, !version.isEmpty {
                    Text("·")
                    Text("v\(version)")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.Relay.secondary)
            .tint(Color.Relay.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding(.horizontal, RelayMetrics.gutter)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .onAppear { launchAtLogin.refresh() }
    }

    private var statusText: String {
        let endpoint = config.endpoint()?.baseURL
        let host = endpoint?.host ?? config.serverHost.trimmed
        let port = endpoint?.port.map(String.init) ?? config.serverPort.trimmed
        let base = "\(config.clientType.displayName) · \(host):\(port)"
        if config.isCurrentConfigTested, let checked = config.lastConnectedString {
            return "\(base) · checked \(checked)"
        }
        return "\(base) · not checked yet"
    }
}

/// A small switch tinted `ready` when on.
private struct RelaySwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Color.Relay.ready)
            .controlSize(.small)
    }
}
