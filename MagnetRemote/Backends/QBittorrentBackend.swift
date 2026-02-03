import Foundation

class QBittorrentBackend: TorrentBackend {
    private var sessionCookie: String?

    func testConnection(url: String, username: String, password: String) async throws {
        try await authenticate(url: url, username: username, password: password)
    }

    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws {
        try await authenticate(url: url, username: username, password: password)

        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let addURL = baseURL.appendingPathComponent("api/v2/torrents/add")

        var request = URLRequest(url: addURL)
        request.httpMethod = "POST"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue(url, forHTTPHeaderField: "Referer")
        request.setValue(url, forHTTPHeaderField: "Origin")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let encodedMagnet = magnet.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw BackendError.encodingFailed
        }
        let body = "urls=\(encodedMagnet)"
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError("Failed to add torrent")
        }
    }

    private func authenticate(url: String, username: String, password: String) async throws {
        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        let loginURL = baseURL.appendingPathComponent("api/v2/auth/login")

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue(url, forHTTPHeaderField: "Referer")
        request.setValue(url, forHTTPHeaderField: "Origin")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "username=\(username)&password=\(password)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.connectionFailed("No response")
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        if responseText != "Ok." {
            throw BackendError.authenticationFailed
        }

        if let cookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
            sessionCookie = cookie.components(separatedBy: ";").first
        }
    }
}
