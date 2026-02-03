import SwiftUI

struct SettingsView: View {
    @StateObject private var config = ServerConfig.shared
    @State private var password: String = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MRLayout.sectionSpacing) {
                // Header
                header

                // Server Configuration
                serverSection

                // Preferences
                preferencesSection

                // About
                aboutSection
            }
            .padding(MRLayout.gutter)
        }
        .background(Color.MR.background)
        .frame(width: 420, height: 520)
        .onAppear {
            password = KeychainService.getPassword() ?? ""
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: MRSpacing.sm) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.MR.accent, Color.MR.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Magnet Remote")
                .font(Font.MR.title1)
                .foregroundColor(Color.MR.textPrimary)

            Text("Send magnet links to your server")
                .font(Font.MR.subheadline)
                .foregroundColor(Color.MR.textSecondary)
        }
        .padding(.vertical, MRSpacing.md)
    }

    // MARK: - Server Section

    private var serverSection: some View {
        MRSectionCard(icon: "server.rack", title: "Server") {
            VStack(spacing: MRSpacing.md) {
                MRPickerField(
                    label: "Client",
                    selection: $config.clientType,
                    displayName: { $0.displayName }
                )

                MRTextField(
                    label: "Server URL",
                    placeholder: "http://192.168.1.100:8080",
                    text: $config.serverURL
                )

                MRTextField(
                    label: "Username",
                    placeholder: "admin",
                    text: $config.username
                )

                MRTextField(
                    label: "Password",
                    placeholder: "••••••••",
                    text: $password,
                    isSecure: true
                )
                .onChange(of: password) { newValue in
                    KeychainService.setPassword(newValue)
                }

                HStack {
                    MRPrimaryButton(
                        title: "Test Connection",
                        icon: "bolt.fill",
                        isLoading: isTesting,
                        isDisabled: config.serverURL.isEmpty
                    ) {
                        testConnection()
                    }

                    if let result = testResult {
                        resultBadge(result)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.mrSpring, value: testResult != nil)
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        MRSectionCard(icon: "slider.horizontal.3", title: "Preferences") {
            VStack(spacing: MRSpacing.sm) {
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
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        MRSectionCard(icon: "info.circle", title: "About") {
            VStack(spacing: MRSpacing.sm) {
                MRInfoRow(label: "Version", value: "1.0.0", icon: "tag")
                MRDivider()
                Text("Magnet Remote registers as your system handler for magnet: links. Click any magnet link in a browser and it will be sent to your configured server.")
                    .font(Font.MR.caption)
                    .foregroundColor(Color.MR.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func resultBadge(_ result: TestResult) -> some View {
        switch result {
        case .success:
            MRStatusBadge(status: .success, message: "Connected")
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

#Preview {
    SettingsView()
}
