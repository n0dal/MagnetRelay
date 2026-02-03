import Foundation

class DelugeBackend: RemoteClient {
    private var sessionCookie: String?

    func testConnection(url: String, username: String, password: String) async throws {
        try await authenticate(url: url, password: password)
    }

    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws {
        try await authenticate(url: url, password: password)

        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let apiURL = baseURL.appendingPathComponent("/json")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "method": "core.add_torrent_magnet",
            "params": [magnet, [String: Any]()],
            "id": Int.random(in: 1...9999)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError("Failed to send magnet")
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw BackendError.serverError(message)
        }
    }

    private func authenticate(url: String, password: String) async throws {
        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let apiURL = baseURL.appendingPathComponent("/json")

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "method": "auth.login",
            "params": [password],
            "id": Int.random(in: 1...9999)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.connectionFailed("No response")
        }

        if let cookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
            sessionCookie = cookie.components(separatedBy: ";").first
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? Bool,
           !result {
            throw BackendError.authenticationFailed
        }
    }
}
