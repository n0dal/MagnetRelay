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
        case .synology: return "Synology Download Station"
        }
    }
}

class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    @AppStorage("clientType") var clientType: ClientType = .qbittorrent
    @AppStorage("serverURL") var serverURL: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true

    private init() {}
}
