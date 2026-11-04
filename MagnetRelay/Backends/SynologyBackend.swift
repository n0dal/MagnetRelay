import Foundation

final class SynologyBackend: RemoteClient {
    private let session: URLSession

    init(session: URLSession = BackendSession.shared) {
        self.session = session
    }

    func testConnection(_ endpoint: ServerEndpoint) async throws {
        // Synology sends credentials as GET query parameters: HTTPS unless on the LAN.
        try validateSecureConnection(endpoint)
        _ = try await authenticate(endpoint)
    }

    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        try validateSecureConnection(endpoint)
        let sid = try await authenticate(endpoint)

        let data = try await get(endpoint.url("webapi", "DownloadStation", "task.cgi"), query: [
            ("api", "SYNO.DownloadStation.Task"),
            ("version", "1"),
            ("method", "create"),
            ("_sid", sid),
            ("uri", magnet)
        ])

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, !success {
            let code = (json["error"] as? [String: Any])?["code"] as? Int ?? 0
            throw BackendError.serverError("Error code: \(code)")
        }
    }

    private func get(_ url: URL, query: [(String, String)]) async throws -> Data {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }
        comps.percentEncodedQuery = FormEncoding.encode(query)
        guard let requestURL = comps.url else { throw BackendError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }
        return data
    }

    private func authenticate(_ endpoint: ServerEndpoint) async throws -> String {
        let data = try await get(endpoint.url("webapi", "auth.cgi"), query: [
            ("api", "SYNO.API.Auth"),
            ("version", "2"),
            ("method", "login"),
            ("account", endpoint.username),
            ("passwd", endpoint.password),
            ("session", "DownloadStation"),
            ("format", "sid")
        ])

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["success"] as? Bool == true,
              let sid = (json["data"] as? [String: Any])?["sid"] as? String else {
            throw BackendError.authenticationFailed
        }
        return sid
    }

    private func validateSecureConnection(_ endpoint: ServerEndpoint) throws {
        let isHTTPS = endpoint.baseURL.scheme?.lowercased() == "https"
        if !isHTTPS && !NetworkAddress.isLocal(host: endpoint.baseURL.host ?? "") {
            throw BackendError.insecureConnection
        }
    }
}
