import Foundation
import SwiftUI

enum ClientType: String, CaseIterable, Identifiable, Codable {
    case qbittorrent
    case transmission
    case deluge
    case rtorrent
    case synology

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qbittorrent: return "qBittorrent"
        case .transmission: return "Transmission"
        case .deluge: return "Deluge"
        case .rtorrent: return "rTorrent"
        case .synology: return "Synology"
        }
    }

    func defaultPort(https: Bool) -> String {
        switch self {
        case .qbittorrent: return "8080"
        case .transmission: return "9091"
        case .deluge: return "8112"
        case .rtorrent: return "8080"
        case .synology: return https ? "5001" : "5000"
        }
    }
}

class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    @AppStorage("clientType") var clientType: ClientType = .qbittorrent
    @AppStorage("useHTTPS") var useHTTPS: Bool = false
    @AppStorage("serverHost") var serverHost: String = ""
    @AppStorage("serverPort") var serverPort: String = "8080"
    @AppStorage("serverPath") var serverPath: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("lastConnectedAt") var lastConnectedAt: Double = 0

    // Stores the config fingerprint when connection was last tested
    @AppStorage("lastTestedConfigHash") var lastTestedConfigHash: String = ""

    private let passwords: PasswordStoring
    private var defaultsObserver: NSObjectProtocol?

    init(store: UserDefaults = .standard, passwords: PasswordStoring = KeychainPasswordStore()) {
        self.passwords = passwords
        _clientType = AppStorage(wrappedValue: .qbittorrent, "clientType", store: store)
        _useHTTPS = AppStorage(wrappedValue: false, "useHTTPS", store: store)
        _serverHost = AppStorage(wrappedValue: "", "serverHost", store: store)
        _serverPort = AppStorage(wrappedValue: "8080", "serverPort", store: store)
        _serverPath = AppStorage(wrappedValue: "", "serverPath", store: store)
        _username = AppStorage(wrappedValue: "", "username", store: store)
        _showNotifications = AppStorage(wrappedValue: true, "showNotifications", store: store)
        _hasCompletedSetup = AppStorage(wrappedValue: false, "hasCompletedSetup", store: store)
        _lastConnectedAt = AppStorage(wrappedValue: 0, "lastConnectedAt", store: store)
        _lastTestedConfigHash = AppStorage(wrappedValue: "", "lastTestedConfigHash", store: store)

        // @AppStorage inside an ObservableObject doesn't publish changes on its own.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: store, queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) }
    }

    var isConfigured: Bool { !serverHost.trimmed.isEmpty }

    func draft() -> ConnectionDraft {
        ConnectionDraft(clientType: clientType, host: serverHost, port: serverPort, useHTTPS: useHTTPS,
                        path: serverPath, username: username, password: passwords.password() ?? "")
    }

    /// Writes the draft. When `savePassword` is true the password goes to the Keychain first;
    /// if that write fails nothing else is changed and this returns false.
    @discardableResult
    func apply(_ draft: ConnectionDraft, savePassword: Bool = true) -> Bool {
        if savePassword, !passwords.setPassword(draft.password) { return false }
        clientType = draft.clientType
        serverHost = draft.host
        serverPort = draft.port
        useHTTPS = draft.useHTTPS
        serverPath = draft.path
        username = draft.username
        return true
    }

    func endpoint() -> ServerEndpoint? { draft().endpoint() }

    /// "host:port" for display, built from the stored fields without reading the Keychain.
    /// A blank port shows the scheme's default.
    var displayAddress: String {
        let d = ConnectionDraft(clientType: clientType, host: serverHost, port: serverPort, useHTTPS: useHTTPS,
                                path: serverPath, username: username, password: "")
        guard let url = d.endpoint()?.baseURL, let host = url.host else { return serverHost.trimmed }
        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        return "\(host):\(port)"
    }

    /// Fingerprint of current connection settings (client, host, port, https, path, username)
    var currentConfigHash: String {
        "\(clientType.rawValue)|\(serverHost)|\(serverPort)|\(useHTTPS)|\(serverPath)|\(username)"
    }

    /// Whether the current config matches the last successfully tested config
    var isCurrentConfigTested: Bool {
        !lastTestedConfigHash.isEmpty && lastTestedConfigHash == currentConfigHash
    }

    /// Mark current config as successfully tested
    func markConfigAsTested() {
        lastTestedConfigHash = currentConfigHash
        lastConnectedAt = Date().timeIntervalSince1970
    }

    // Computed property for last connection date (only valid if config matches)
    var lastConnectedDate: Date? {
        guard lastConnectedAt > 0, isCurrentConfigTested else { return nil }
        return Date(timeIntervalSince1970: lastConnectedAt)
    }

    // Human-readable last connection time (only shown if config unchanged)
    var lastConnectedString: String? {
        guard let date = lastConnectedDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
