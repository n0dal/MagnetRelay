import Foundation

protocol RemoteClient {
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

    /// Maximum retry attempts for transient failures
    static let maxRetries: Int = 2

    /// Delay between retries in seconds
    static let retryDelay: TimeInterval = 1.0

    /// Configured URLSession with timeout
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = defaultTimeout
        config.timeoutIntervalForResource = defaultTimeout * 2
        return URLSession(configuration: config)
    }()

    /// Execute an async operation with automatic retry for transient failures
    static func withRetry<T>(
        maxAttempts: Int = maxRetries + 1,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry non-transient errors
                if !isTransientError(error) {
                    throw error
                }

                // Don't delay after last attempt
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? BackendError.connectionFailed("Unknown error after retries")
    }

    /// Determine if an error is transient and worth retrying
    private static func isTransientError(_ error: Error) -> Bool {
        // URLError codes that are worth retrying
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        // BackendError cases that might be transient
        if let backendError = error as? BackendError {
            switch backendError {
            case .timeout, .connectionFailed:
                return true
            default:
                return false
            }
        }

        return false
    }
}

class BackendFactory {
    static func create(for type: ClientType) -> RemoteClient {
        switch type {
        case .qbittorrent:
            return QBittorrentBackend()
        case .transmission:
            return TransmissionBackend()
        case .deluge:
            return DelugeBackend()
        case .rtorrent:
            return RRemoteClient()
        case .synology:
            return SynologyBackend()
        }
    }
}
