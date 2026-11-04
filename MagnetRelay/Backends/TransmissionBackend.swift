import Foundation

final class TransmissionBackend: RemoteClient {
    private let session: URLSession

    init(session: URLSession = BackendSession.shared) {
        self.session = session
    }

    func testConnection(_ endpoint: ServerEndpoint) async throws {
        _ = try await getSessionId(endpoint)
    }

    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        let sessionId = try await getSessionId(endpoint)

        var request = rpcRequest(endpoint)
        request.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "method": "torrent-add",
            "arguments": ["filename": magnet]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        if http.statusCode == 401 { throw BackendError.authenticationFailed }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? String, result != "success" {
            throw BackendError.serverError(result)
        }
    }

    private func rpcRequest(_ endpoint: ServerEndpoint) -> URLRequest {
        var request = URLRequest(url: endpoint.url("transmission", "rpc"))
        request.httpMethod = "POST"
        request.setBasicAuth(username: endpoint.username, password: endpoint.password)
        return request
    }

    /// Transmission hands out its session id on a 409 response.
    private func getSessionId(_ endpoint: ServerEndpoint) async throws -> String {
        let (_, response) = try await session.data(for: rpcRequest(endpoint))
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }

        if http.statusCode == 401 { throw BackendError.authenticationFailed }
        if http.statusCode == 409 || http.statusCode == 200,
           let id = http.value(forHTTPHeaderField: "X-Transmission-Session-Id") {
            return id
        }
        throw BackendError.httpStatus(http.statusCode)
    }
}
