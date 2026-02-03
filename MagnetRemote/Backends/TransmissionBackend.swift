import Foundation

class TransmissionBackend: RemoteClient {
    private var sessionId: String?

    func testConnection(url: String, username: String, password: String) async throws {
        // Transmission requires a session ID obtained via 409 response
        try await getSessionId(url: url, username: username, password: password)
    }

    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws {
        try await getSessionId(url: url, username: username, password: password)

        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let rpcURL = baseURL.appendingPathComponent("/transmission/rpc")

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let payload: [String: Any] = [
            "method": "torrent-add",
            "arguments": ["filename": magnet]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError("Failed to send magnet")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? String,
           result != "success" {
            throw BackendError.serverError(result)
        }
    }

    private func getSessionId(url: String, username: String, password: String) async throws {
        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let rpcURL = baseURL.appendingPathComponent("/transmission/rpc")

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"

        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let (_, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.connectionFailed("No response")
        }

        // Transmission returns 409 with session ID header on first request
        if httpResponse.statusCode == 409 || httpResponse.statusCode == 200 {
            if let newSessionId = httpResponse.value(forHTTPHeaderField: "X-Transmission-Session-Id") {
                sessionId = newSessionId
                return
            }
        }

        if httpResponse.statusCode == 401 {
            throw BackendError.authenticationFailed
        }

        throw BackendError.connectionFailed("Status: \(httpResponse.statusCode)")
    }
}
