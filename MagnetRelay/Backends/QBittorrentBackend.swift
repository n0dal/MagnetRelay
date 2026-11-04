import Foundation

final class QBittorrentBackend: RemoteClient {
    private let session: URLSession

    init(session: URLSession = BackendSession.shared) {
        self.session = session
    }

    func testConnection(_ endpoint: ServerEndpoint) async throws {
        _ = try await authenticate(endpoint)
    }

    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        let cookie = try await authenticate(endpoint)

        var request = makeRequest(endpoint.url("api", "v2", "torrents", "add"), endpoint: endpoint)
        if let cookie { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
        request.httpBody = FormEncoding.encode([("urls", magnet)]).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        if http.statusCode == 403 || http.statusCode == 401 { throw BackendError.authenticationFailed }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }
        if String(data: data, encoding: .utf8)?.trimmed == "Fails." {
            throw BackendError.serverError("qBittorrent rejected the link")
        }
    }

    private func makeRequest(_ url: URL, endpoint: ServerEndpoint) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let origin = endpoint.baseURL.absoluteString
        request.setValue(origin, forHTTPHeaderField: "Referer")
        request.setValue(origin, forHTTPHeaderField: "Origin")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// Logs in and returns the session cookie (`SID=...`), if any.
    private func authenticate(_ endpoint: ServerEndpoint) async throws -> String? {
        var request = makeRequest(endpoint.url("api", "v2", "auth", "login"), endpoint: endpoint)
        request.httpBody = FormEncoding.encode([("username", endpoint.username),
                                                ("password", endpoint.password)]).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        if http.statusCode == 403 { throw BackendError.authenticationFailed }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }

        guard String(data: data, encoding: .utf8)?.trimmed == "Ok." else { throw BackendError.authenticationFailed }
        return http.value(forHTTPHeaderField: "Set-Cookie")?.components(separatedBy: ";").first
    }
}
