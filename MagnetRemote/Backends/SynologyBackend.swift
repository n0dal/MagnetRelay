import Foundation

class SynologyBackend: RemoteClient {
    private var sid: String?

    func testConnection(url: String, username: String, password: String) async throws {
        // Synology sends credentials as GET query parameters - require HTTPS
        try validateSecureConnection(url: url)
        try await authenticate(url: url, username: username, password: password)
    }

    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws {
        try validateSecureConnection(url: url)
        try await authenticate(url: url, username: username, password: password)

        guard let baseURL = URL(string: url),
              var components = URLComponents(url: baseURL.appendingPathComponent("/webapi/DownloadStation/task.cgi"), resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.DownloadStation.Task"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "create"),
            URLQueryItem(name: "_sid", value: sid),
            URLQueryItem(name: "uri", value: magnet)
        ]

        guard let requestURL = components.url else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError("Failed to send magnet")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           !success {
            let errorCode = (json["error"] as? [String: Any])?["code"] as? Int ?? 0
            throw BackendError.serverError("Error code: \(errorCode)")
        }
    }

    private func authenticate(url: String, username: String, password: String) async throws {
        guard let baseURL = URL(string: url),
              var components = URLComponents(url: baseURL.appendingPathComponent("/webapi/auth.cgi"), resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Auth"),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "method", value: "login"),
            URLQueryItem(name: "account", value: username),
            URLQueryItem(name: "passwd", value: password),
            URLQueryItem(name: "session", value: "DownloadStation"),
            URLQueryItem(name: "format", value: "sid")
        ]

        guard let requestURL = components.url else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.connectionFailed("No response")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool,
              success,
              let dataObj = json["data"] as? [String: Any],
              let sessionId = dataObj["sid"] as? String else {
            throw BackendError.authenticationFailed
        }

        sid = sessionId
    }

    /// Validates that the connection uses HTTPS
    /// Synology API sends credentials as GET query parameters which are visible in server logs
    /// and can be intercepted on insecure connections
    private func validateSecureConnection(url: String) throws {
        guard let urlComponents = URLComponents(string: url) else {
            throw BackendError.invalidURL
        }

        if urlComponents.scheme?.lowercased() != "https" {
            throw BackendError.insecureConnection(
                "Synology requires HTTPS. Credentials would be visible in URL."
            )
        }
    }
}
