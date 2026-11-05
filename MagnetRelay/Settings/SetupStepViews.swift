import SwiftUI

/// The three setup steps: header (mark, name, progress), the step's content, and the footer.
struct SetupFlowView: View {
    @ObservedObject var model: SetupFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ZStack(alignment: .topLeading) {
                switch model.step {
                case .client: ClientStepView(model: model).transition(.opacity)
                case .address: AddressStepView(model: model).transition(.opacity)
                case .signIn: SignInStepView(model: model).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.step)

            Spacer(minLength: 0)

            footer
        }
        .padding(.horizontal, RelayMetrics.gutter)
        .padding(.top, RelayMetrics.panelTopInset)
        .padding(.bottom, 22)
        .onDisappear { model.cancelConnect() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            MagnetMark(size: 30)
            Text("MagnetRelay")
                .font(Font.Relay.label)
                .foregroundStyle(Color.Relay.ink)
            Spacer()
            StepProgress(current: model.step.rawValue, total: 3)
        }
    }

    private var footer: some View {
        HStack {
            leftFooterItem
            Spacer()
            Button {
                primaryAction()
            } label: {
                if model.isConnecting {
                    HStack(spacing: 8) {
                        ConnectingSpinner()
                        Text("Connecting…")
                    }
                } else {
                    Text(model.step == .signIn ? "Connect" : "Continue")
                }
            }
            .buttonStyle(RelayPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canContinue && !model.isConnecting)
        }
    }

    @ViewBuilder
    private var leftFooterItem: some View {
        if model.isConnecting {
            FooterTextButton(title: "Cancel") { model.cancelConnect() }
        } else if model.step == .client {
            if model.isChangingServer {
                FooterTextButton(title: "Cancel") { model.back() }
            } else {
                Text("Step 1 of 3")
                    .font(Font.Relay.body)
                    .foregroundStyle(Color.Relay.secondary)
            }
        } else {
            FooterTextButton(title: "Back") { model.back() }
        }
    }

    private func primaryAction() {
        guard !model.isConnecting, model.canContinue else { return }
        if model.step == .signIn {
            Task { await model.connect() }
        } else {
            model.next()
        }
    }
}

// MARK: - Steps

private struct StepHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .relayHeading()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(Font.Relay.body)
                .foregroundStyle(Color.Relay.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 22)
        .accessibilityElement(children: .combine)
    }
}

private struct ClientStepView: View {
    @ObservedObject var model: SetupFlowModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: "Which app runs your downloads?",
                        subtitle: "Pick the one on your server or NAS. You can change it later.")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ClientType.allCases) { client in
                    ClientTile(name: client.displayName, isSelected: model.draft.clientType == client) {
                        model.selectClient(client)
                    }
                }
            }
            .padding(.top, 18)
        }
    }
}

private struct AddressStepView: View {
    @ObservedObject var model: SetupFlowModel

    private var client: String { model.draft.clientType.displayName }

    /// Synology over plain HTTP to a local address: say the password isn't encrypted.
    private var showsUnencryptedNote: Bool {
        guard model.draft.clientType == .synology, let url = model.draft.endpoint()?.baseURL,
              url.scheme == "http", let host = url.host else { return false }
        return NetworkAddress.isLocal(host: host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: "Where is \(client)?",
                        subtitle: "The address you'd type in a browser to open its web page.")
            RelayCard {
                RelayRow(title: "Address") {
                    RowTextField(label: "Address", placeholder: "192.168.0.100", text: $model.draft.host)
                }
                RelayRow(title: "Port") {
                    // A blank port is allowed and means the scheme's default (80 / 443).
                    RowTextField(label: "Port", placeholder: "Default", text: portBinding)
                }
                RelayRow(title: "Use HTTPS") {
                    Toggle("Use HTTPS", isOn: Binding(get: { model.draft.useHTTPS }, set: { model.setHTTPS($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color.Relay.ready)
                        .controlSize(.small)
                }
                if model.showsPath {
                    RelayRow(title: "Path") {
                        RowTextField(label: "Path", placeholder: model.draft.clientType == .rtorrent ? "/RPC2" : "/qbittorrent",
                                     text: $model.draft.path)
                    }
                }
            }
            .padding(.top, 18)

            if !model.showsPath {
                HStack(spacing: 4) {
                    Text("Behind a reverse proxy?")
                    Button {
                        model.showsPath = true
                    } label: {
                        Text("Add a path").underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a path")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Color.Relay.secondary)
                .padding(.top, 10)
                .padding(.horizontal, 2)
            }

            if showsUnencryptedNote {
                Text("Your password is sent unencrypted on your home network.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.Relay.secondary)
                    .padding(.top, 10)
                    .padding(.horizontal, 2)
            }
        }
    }

    /// Digits only, at most 5.
    private var portBinding: Binding<String> {
        Binding(
            get: { model.draft.port },
            set: { model.draft.port = String($0.filter(\.isASCIIDigit).prefix(5)) }
        )
    }
}

private struct SignInStepView: View {
    @ObservedObject var model: SetupFlowModel
    @State private var showsPassword = false

    private var client: String { model.draft.clientType.displayName }
    private var isDeluge: Bool { model.draft.clientType == .deluge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeading(title: "Sign in to \(client)",
                        subtitle: "The same login you use on its web page. Saved in your Keychain.")
            RelayCard {
                if !isDeluge {
                    RelayRow(title: "Username") {
                        RowTextField(label: "Username", placeholder: "admin", text: $model.draft.username)
                    }
                }
                RelayRow(title: "Password") {
                    HStack(spacing: 6) {
                        Group {
                            if showsPassword {
                                RowTextField(label: "Password", placeholder: model.passwordPlaceholder, text: $model.draft.password)
                            } else {
                                SecureField(model.passwordPlaceholder, text: $model.draft.password)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Color.Relay.ink)
                                    .accessibilityLabel("Password")
                            }
                        }
                        Button {
                            showsPassword.toggle()
                        } label: {
                            Image(systemName: showsPassword ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.Relay.secondary)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
                    }
                }
            }
            .disabled(model.isConnecting)
            .padding(.top, 18)

            if isDeluge {
                Text("Deluge only asks for a password.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.Relay.secondary)
                    .padding(.top, 10)
                    .padding(.horizontal, 2)
            }

            if let error = model.errorMessage {
                InlineError(text: error)
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - Small pieces

/// A plain, right-aligned text field for the trailing side of a `RelayRow`.
private struct RowTextField: View {
    /// What VoiceOver reads (the row title), rather than the placeholder.
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Color.Relay.ink)
            .autocorrectionDisabled()
            .frame(maxWidth: 240)
            .accessibilityLabel(label)
    }
}

/// Text-only footer button in `ink` (Back / Cancel).
private struct FooterTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.Relay.body)
                .foregroundStyle(Color.Relay.ink)
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small spinner drawn for the opposite appearance so it reads on the `ink` button fill.
private struct ConnectingSpinner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ProgressView()
            .controlSize(.small)
            .environment(\.colorScheme, colorScheme == .dark ? .light : .dark)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
