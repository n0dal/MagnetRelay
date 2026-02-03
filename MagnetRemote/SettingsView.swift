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
        Form {
            Section {
                Picker("Client", selection: $config.clientType) {
                    ForEach(ClientType.allCases) { client in
                        Text(client.displayName).tag(client)
                    }
                }
                .pickerStyle(.menu)

                TextField("Server URL", text: $config.serverURL)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g., http://192.168.1.100:8080")

                TextField("Username", text: $config.username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        password = KeychainService.getPassword() ?? ""
                    }
                    .onChange(of: password) { newValue in
                        KeychainService.setPassword(newValue)
                    }
            } header: {
                Text("Server Configuration")
            }

            Section {
                HStack {
                    Button(action: testConnection) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTesting || config.serverURL.isEmpty)

                    Spacer()

                    if let result = testResult {
                        resultBadge(result)
                    }
                }
            }

            Section {
                Toggle("Launch at Login", isOn: $config.launchAtLogin)
                    .onChange(of: config.launchAtLogin) { newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }

                Toggle("Show Notifications", isOn: $config.showNotifications)
            } header: {
                Text("Preferences")
            }

            Section {
                Text("Magnet Remote registers as your system handler for magnet: links. When you click a magnet link in any app, it will be sent to your configured server.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("How It Works")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
        .padding()
    }

    @ViewBuilder
    private func resultBadge(_ result: TestResult) -> some View {
        switch result {
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .help(message)
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
