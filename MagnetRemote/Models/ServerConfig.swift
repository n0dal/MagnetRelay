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

    var defaultPort: String {
        switch self {
        case .qbittorrent: return "8080"
        case .transmission: return "9091"
        case .deluge: return "8112"
        case .rtorrent: return "8080"
        case .synology: return "5000"
        }
    }

    /// Whether this backend has been tested against a real server
    var isExperimental: Bool {
        switch self {
        case .transmission, .rtorrent:
            return false  // Well tested
        case .qbittorrent, .deluge, .synology:
            return true   // Needs real-world testing
        }
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
    @AppStorage("username") var username: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("lastConnectedAt") var lastConnectedAt: Double = 0
    @AppStorage("bannerDismissed") var bannerDismissed: Bool = false

    // Computed property for last connection date
    var lastConnectedDate: Date? {
        guard lastConnectedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: lastConnectedAt)
    }

    // Human-readable last connection time
    var lastConnectedString: String? {
        guard let date = lastConnectedDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Legacy support - computed property
    var serverURL: String {
        get {
            let proto = useHTTPS ? "https" : "http"
            let port = serverPort.isEmpty ? "" : ":\(serverPort)"
            return "\(proto)://\(serverHost)\(port)"
        }
        set {
            // Parse URL for backwards compatibility
            if let url = URL(string: newValue) {
                useHTTPS = url.scheme == "https"
                serverHost = url.host ?? ""
                if let port = url.port {
                    serverPort = String(port)
                }
            }
        }
    }

    private init() {}
}
