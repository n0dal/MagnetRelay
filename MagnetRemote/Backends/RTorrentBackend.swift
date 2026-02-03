import Foundation

class RTorrentBackend: TorrentBackend {
    func testConnection(url: String, username: String, password: String) async throws {
        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        // rTorrent uses XML-RPC, test with system.listMethods
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")

        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let xml = """
        <?xml version="1.0"?>
        <methodCall>
            <methodName>system.listMethods</methodName>
            <params></params>
        </methodCall>
        """
        request.httpBody = xml.data(using: .utf8)

        let (_, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.connectionFailed("No response")
        }

        if httpResponse.statusCode == 401 {
            throw BackendError.authenticationFailed
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw BackendError.connectionFailed("Status: \(httpResponse.statusCode)")
        }
    }

    func addMagnet(_ magnet: String, url: String, username: String, password: String) async throws {
        guard let baseURL = URL(string: url) else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")

        if !username.isEmpty {
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        // Escape XML special characters in magnet URL
        let escapedMagnet = magnet
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let xml = """
        <?xml version="1.0"?>
        <methodCall>
            <methodName>load.start</methodName>
            <params>
                <param><value><string></string></value></param>
                <param><value><string>\(escapedMagnet)</string></value></param>
            </params>
        </methodCall>
        """
        request.httpBody = xml.data(using: .utf8)

        let (_, response) = try await BackendSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BackendError.serverError("Failed to add torrent")
        }
    }
}
