import SwiftUI

struct SettingsView: View {
    @StateObject private var config = ServerConfig.shared
    @State private var password: String = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showPreferences = false
    @State private var isInitialLoad = true

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(spacing: MRSpacing.lg) {
            // Header with preferences button
            header

            // Welcome banner for first-time users
            if !config.hasCompletedSetup {
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
        .frame(width: 480, height: config.hasCompletedSetup ? 460 : 520)
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
        }
        .padding(MRSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.MR.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: MRRadius.md, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: MRSpacing.sm) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.MR.accent, Color.MR.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text("Magnet Remote")
                        .font(Font.MR.title3)
                        .foregroundColor(Color.MR.textPrimary)

                    Text("v1.0.0")
                        .font(Font.MR.caption)
                        .foregroundColor(Color.MR.textTertiary)
                }
            }

            Spacer()

            MRIconButton(icon: "gearshape") {
                showPreferences = true
            }
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: MRSpacing.sm) {
            MRFieldRow(icon: "app.connected.to.app.below.fill", label: "CLIENT")

            MRClientSelector(selection: $config.clientType)
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
                    placeholder: "192.168.1.100",
                    text: $config.serverHost
                )

                Text(":")
                    .font(Font.MR.title3)
                    .foregroundColor(Color.MR.textTertiary)

                MRCompactInput(
                    placeholder: "Port",
                    text: $config.serverPort,
                    width: 72
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
                    placeholder: "admin",
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
                MRPrimaryButton(
                    title: "Test Connection",
                    icon: "bolt.fill",
                    isLoading: isTesting,
                    isDisabled: config.serverHost.isEmpty
                ) {
                    testConnection()
                }

                if let result = testResult {
                    resultBadge(result)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.mrSpring, value: testResult != nil)

            if testResult == nil {
                Text("Click any magnet link and it will be sent to your server")
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

        Task {
            do {
                let backend = BackendFactory.create(for: config.clientType)
                try await backend.testConnection(
                    url: config.serverURL,
                    username: config.username,
                    password: password
                )
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                    // Mark setup as complete on successful connection
                    if !config.hasCompletedSetup {
                        withAnimation(.mrQuick) {
                            config.hasCompletedSetup = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
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
                    subtitle: "Get notified when torrents are added",
                    icon: "bell.fill",
                    isOn: $config.showNotifications
                )
            }

            MRDivider()

            // About
            VStack(alignment: .leading, spacing: MRSpacing.sm) {
                Text("About")
                    .font(Font.MR.headline)
                    .foregroundColor(Color.MR.textPrimary)

                Text("Magnet Remote registers as your system handler for magnet: links. Click any magnet link in a browser and it will be sent to your configured server.")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(MRLayout.gutter)
        .frame(width: 340, height: 320)
        .background(Color.MR.background)
    }
}

#Preview {
    SettingsView()
}
