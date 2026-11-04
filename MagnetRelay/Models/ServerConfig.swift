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

    // Shorter names for compact UI (client chips)
    var shortName: String {
        switch self {
        case .qbittorrent: return "qBit"
        case .transmission: return "Trans"
        case .deluge: return "Deluge"
        case .rtorrent: return "rTorrent"
        case .synology: return "Synology"
        }
    }

    var icon: String {
        switch self {
        case .qbittorrent: return "arrow.down.to.line.circle.fill"
        case .transmission: return "gear.circle.fill"
        case .deluge: return "drop.circle.fill"
        case .rtorrent: return "terminal.fill"
        case .synology: return "externaldrive.fill.badge.wifi"
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

    /// Whether this backend has been tested against a real server
    var isExperimental: Bool {
        // All backends have been tested
        return false
    }

    /// Warning message for experimental backends
    var experimentalWarning: String? {
        guard isExperimental else { return nil }
        return "This client hasn't been fully tested. Please report issues."
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
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("lastConnectedAt") var lastConnectedAt: Double = 0
    @AppStorage("bannerDismissed") var bannerDismissed: Bool = false

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
        _launchAtLogin = AppStorage(wrappedValue: false, "launchAtLogin", store: store)
        _showNotifications = AppStorage(wrappedValue: true, "showNotifications", store: store)
        _hasCompletedSetup = AppStorage(wrappedValue: false, "hasCompletedSetup", store: store)
        _lastConnectedAt = AppStorage(wrappedValue: 0, "lastConnectedAt", store: store)
        _bannerDismissed = AppStorage(wrappedValue: false, "bannerDismissed", store: store)
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

    func apply(_ draft: ConnectionDraft) {
        clientType = draft.clientType
        serverHost = draft.host
        serverPort = draft.port
        useHTTPS = draft.useHTTPS
        serverPath = draft.path
        username = draft.username
        passwords.setPassword(draft.password)
    }

    func endpoint() -> ServerEndpoint? { draft().endpoint() }

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
