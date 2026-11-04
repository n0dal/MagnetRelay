import Foundation

final class DelugeBackend: RemoteClient {
    private let session: URLSession
    private var sessionCookie: String?

    init(session: URLSession = BackendSession.shared) {
        self.session = session
    }

    func testConnection(_ endpoint: ServerEndpoint) async throws {
        try await authenticate(endpoint)
        try await ensureDaemonConnected(endpoint)
    }

    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        try await authenticate(endpoint)
        try await ensureDaemonConnected(endpoint)
        _ = try await call("core.add_torrent_magnet", params: [magnet, [String: Any]()], endpoint)
    }

    /// Deluge username is ignored by design; only the password is used.
    private func authenticate(_ endpoint: ServerEndpoint) async throws {
        let result = try await call("auth.login", params: [endpoint.password], endpoint)
        if let ok = result as? Bool, !ok { throw BackendError.authenticationFailed }
    }

    /// The Web UI must be attached to a daemon before core.* calls work.
    private func ensureDaemonConnected(_ endpoint: ServerEndpoint) async throws {
        if try await call("web.connected", params: [], endpoint) as? Bool == true { return }

        let hosts = try await call("web.get_hosts", params: [], endpoint) as? [[Any]] ?? []
        guard let hostId = hosts.first?.first as? String else { throw BackendError.daemonNotConnected }
        _ = try await call("web.connect", params: [hostId], endpoint)
    }

    private func call(_ method: String, params: [Any], _ endpoint: ServerEndpoint) async throws -> Any? {
        var request = URLRequest(url: endpoint.url("json"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionCookie { request.setValue(sessionCookie, forHTTPHeaderField: "Cookie") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "method": method, "params": params, "id": 1
        ] as [String: Any])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }

        if let cookie = http.value(forHTTPHeaderField: "Set-Cookie") {
            sessionCookie = cookie.components(separatedBy: ";").first
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error"] as? [String: Any], let message = error["message"] as? String {
            throw BackendError.serverError(message)
        }
        return json?["result"]
    }
}
