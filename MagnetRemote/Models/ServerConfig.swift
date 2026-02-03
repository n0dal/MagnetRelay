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

    var icon: String {
        switch self {
        case .qbittorrent: return "arrow.down.circle"
        case .transmission: return "gear.circle"
        case .deluge: return "flame"
        case .rtorrent: return "terminal"
        case .synology: return "externaldrive.connected.to.line.below"
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
