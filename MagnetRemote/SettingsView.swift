import SwiftUI

struct SettingsView: View {
    @StateObject private var config = ServerConfig.shared
    @State private var password: String = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showPreferences = false
    @State private var isInitialLoad = true
    @State private var connectionTask: Task<Void, Never>?

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: MRSpacing.lg) {
            // Header with preferences button
            header

            // Welcome banner for first-time users
            if !config.hasCompletedSetup && !config.bannerDismissed {
                setupBanner
            }

            // Client selector
            clientSection

            // Server configuration
            serverSection

            // Credentials
            credentialsSection

            // Test connection
            connectionSection

            Spacer(minLength: 0)
        }
        .padding(MRLayout.gutter + 4)
        .background(Color.MR.background)
        .frame(width: 480, height: (config.hasCompletedSetup || config.bannerDismissed) ? 460 : 520)
        .onAppear {
            password = KeychainService.getPassword() ?? ""
            // Delay flag reset to avoid onChange triggering during load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInitialLoad = false
            }
        }
        .onChange(of: config.clientType) { newValue in
            // Update port to client default if port is empty or matches another client's default
            let allDefaults = ClientType.allCases.map { $0.defaultPort }
            if config.serverPort.isEmpty || allDefaults.contains(config.serverPort) {
                config.serverPort = newValue.defaultPort
            }
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesSheet(config: config)
        }
    }

    // MARK: - Setup Banner

    private var setupBanner: some View {
        HStack(spacing: MRSpacing.md) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.MR.accent)

            VStack(alignment: .leading, spacing: MRSpacing.xxs) {
                Text("Welcome! Configure your server below.")
                    .font(Font.MR.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.MR.textPrimary)

                Text("Test the connection to save settings and enable magnet link handling.")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Dismiss button
            Button {
                withAnimation(.mrQuick) {
                    config.bannerDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.MR.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.MR.surface.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss welcome banner")
        }
        .padding(MRSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.MR.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome banner. Configure your server and test the connection to enable magnet link handling.")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: MRSpacing.sm) {
                // Use the actual app icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Magnet Remote")
                        .font(Font.MR.title3)
                        .foregroundColor(Color.MR.textPrimary)

                    // Connection status indicator
                    MRConnectionStatus(
                        isConfigured: config.isCurrentConfigTested,
                        lastConnected: config.lastConnectedString
                    )
                }
            }

            Spacer()

            MRIconButton(icon: "gearshape", accessibilityText: "Open preferences") {
                showPreferences = true
            }
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: MRSpacing.sm) {
            MRFieldRow(icon: "app.connected.to.app.below.fill", label: "CLIENT")

            MRClientSelector(selection: $config.clientType)

            // Experimental warning
            if config.clientType.isExperimental {
                HStack(spacing: MRSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(config.clientType.experimentalWarning ?? "")
                        .font(Font.MR.caption)
                }
                .foregroundColor(Color.MR.warning)
                .padding(.top, MRSpacing.xxs)
            }
        }
    }

    // MARK: - Server Section

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: MRSpacing.sm) {
            MRFieldRow(icon: "server.rack", label: "SERVER")

            HStack(spacing: MRSpacing.sm) {
                MRProtocolToggle(useHTTPS: $config.useHTTPS)

                MRInputField(
                    icon: "globe",
                    label: "Host",
                    placeholder: "nas.local or IP",
                    text: $config.serverHost
                )

                Text(":")
                    .font(Font.MR.title3)
                    .foregroundColor(Color.MR.textTertiary)

                MRCompactInput(
                    placeholder: "Port",
                    text: $config.serverPort,
                    width: 72,
                    numericOnly: true
                )
            }
        }
    }

    // MARK: - Credentials Section

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: MRSpacing.sm) {
            MRFieldRow(icon: "person.badge.key", label: "CREDENTIALS")

            HStack(spacing: MRSpacing.sm) {
                MRInputField(
                    icon: "person",
                    label: "Username",
                    placeholder: "username",
                    text: $config.username
                )

                MRInputField(
                    icon: "key",
                    label: "Password",
                    placeholder: "••••••••",
                    text: $password,
                    isSecure: true
                )
                .onChange(of: password) { newValue in
                    guard !isInitialLoad else { return }
                    KeychainService.setPassword(newValue)
                }
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(spacing: MRSpacing.md) {
            HStack(spacing: MRSpacing.md) {
                if isTesting {
                    // Cancel button while testing
                    MRSecondaryButton(
                        title: "Cancel",
                        icon: "xmark"
                    ) {
                        cancelTest()
                    }
                } else {
                    // Test connection button
                    MRPrimaryButton(
                        title: "Test Connection",
                        icon: "bolt.fill",
                        isLoading: false,
                        isDisabled: config.serverHost.isEmpty
                    ) {
                        testConnection()
                    }
                }

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                }

                if let result = testResult {
                    resultBadge(result)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.mrSpring, value: isTesting)
            .animation(.mrSpring, value: testResult != nil)

            if testResult == nil && !isTesting {
                Text("Click any magnet link and it will be sent to your server")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
                    .multilineTextAlignment(.center)
            } else if isTesting {
                Text("Testing connection...")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func resultBadge(_ result: TestResult) -> some View {
        switch result {
        case .success:
            MRStatusBadge(status: .success, message: "Saved & Connected")
        case .failure(let message):
            MRStatusBadge(status: .error, message: message)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        connectionTask = Task {
            do {
                let backend = BackendFactory.create(for: config.clientType)
                try await backend.testConnection(
                    url: config.serverURL,
                    username: config.username,
                    password: password
                )

                // Check if cancelled before updating UI
                if Task.isCancelled { return }

                await MainActor.run {
                    testResult = .success
                    isTesting = false
                    // Mark this config as tested and save connection time
                    config.markConfigAsTested()
                    // Mark setup as complete on successful connection
                    if !config.hasCompletedSetup {
                        withAnimation(.mrQuick) {
                            config.hasCompletedSetup = true
                        }
                    }
                }
            } catch {
                // Check if cancelled before showing error
                if Task.isCancelled { return }

                await MainActor.run {
                    // Use user-friendly error message
                    let friendlyMessage = ConnectionError.userFriendlyMessage(from: error)
                    testResult = .failure(friendlyMessage)
                    isTesting = false
                }
            }
        }
    }

    private func cancelTest() {
        connectionTask?.cancel()
        connectionTask = nil
        isTesting = false
        testResult = .failure("Test cancelled")
    }
}

// MARK: - Preferences Sheet

struct PreferencesSheet: View {
    @ObservedObject var config: ServerConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: MRLayout.sectionSpacing) {
            // Header
            HStack {
                Text("Preferences")
                    .font(Font.MR.title2)
                    .foregroundColor(Color.MR.textPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.MR.accent)
                .font(Font.MR.headline)
            }

            MRDivider()

            // Toggles
            VStack(spacing: MRSpacing.md) {
                MRToggleRow(
                    title: "Launch at Login",
                    subtitle: "Start automatically when you log in",
                    icon: "power",
                    isOn: $config.launchAtLogin
                )
                .onChange(of: config.launchAtLogin) { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                }

                MRDivider()

                MRToggleRow(
                    title: "Show Notifications",
                    subtitle: "Get notified when magnets are sent",
                    icon: "bell.fill",
                    isOn: $config.showNotifications
                )
            }

            MRDivider()

            // Data & Privacy
            VStack(spacing: MRSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: MRSpacing.xxs) {
                        Text("Recent Magnets")
                            .font(Font.MR.subheadline)
                            .foregroundColor(Color.MR.textPrimary)
                        Text("\(RecentMagnets.shared.items.count) items stored locally")
                            .font(Font.MR.caption)
                            .foregroundColor(Color.MR.textTertiary)
                    }
                    Spacer()
                    Button("Clear") {
                        RecentMagnets.shared.clear()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.MR.accent)
                    .font(Font.MR.subheadline)
                    .disabled(RecentMagnets.shared.items.isEmpty)
                    .opacity(RecentMagnets.shared.items.isEmpty ? 0.5 : 1)
                }

                HStack {
                    Text("Privacy Policy")
                        .font(Font.MR.subheadline)
                        .foregroundColor(Color.MR.textPrimary)
                    Spacer()
                    Button("View") {
                        if let url = URL(string: "https://github.com/pgpillar/MagnetRemote/blob/main/PRIVACY.md") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.MR.accent)
                    .font(Font.MR.subheadline)
                }
            }

            MRDivider()

            // About
            Text("Magnet Remote registers as your system handler for magnet: links. Click any magnet link in a browser and it will be sent to your configured server.")
                .font(Font.MR.caption)
                .foregroundColor(Color.MR.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(MRLayout.gutter)
        .frame(width: 340, height: 380)
        .background(Color.MR.background)
    }
}

#Preview {
    SettingsView()
}
