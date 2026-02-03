import Foundation

protocol TorrentBackend {
    func testConnection(url: String, username: String, password: String) async throws
    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws
}

enum BackendError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case connectionFailed(String)
    case serverError(String)
    case timeout
    case insecureConnection(String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .authenticationFailed:
            return "Authentication failed"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .serverError(let reason):
            return "Server error: \(reason)"
        case .timeout:
            return "Connection timed out"
        case .insecureConnection(let reason):
            return "Insecure connection: \(reason)"
        case .encodingFailed:
            return "Failed to encode magnet URL"
        }
    }
}

/// Shared URLSession configuration for all backends with timeout
enum BackendSession {
    /// Default timeout in seconds for backend requests
    static let defaultTimeout: TimeInterval = 30

    /// Configured URLSession with timeout
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = defaultTimeout
        config.timeoutIntervalForResource = defaultTimeout * 2
        return URLSession(configuration: config)
    }()
}

class BackendFactory {
    static func create(for type: ClientType) -> TorrentBackend {
        switch type {
        case .qbittorrent:
            return QBittorrentBackend()
        case .transmission:
            return TransmissionBackend()
        case .deluge:
            return DelugeBackend()
        case .rtorrent:
            return RTorrentBackend()
        case .synology:
            return SynologyBackend()
        }
    }
}
