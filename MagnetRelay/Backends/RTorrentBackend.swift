import Foundation

final class RTorrentBackend: RemoteClient {
    private let session: URLSession

    init(session: URLSession = BackendSession.shared) {
        self.session = session
    }

    func testConnection(_ endpoint: ServerEndpoint) async throws {
        try await send("""
        <?xml version="1.0"?>
        <methodCall>
            <methodName>system.listMethods</methodName>
            <params></params>
        </methodCall>
        """, to: endpoint)
    }

    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        let escaped = magnet
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        try await send("""
        <?xml version="1.0"?>
        <methodCall>
            <methodName>load.start</methodName>
            <params>
                <param><value><string></string></value></param>
                <param><value><string>\(escaped)</string></value></param>
            </params>
        </methodCall>
        """, to: endpoint)
    }

    private func send(_ xml: String, to endpoint: ServerEndpoint) async throws {
        var request = URLRequest(url: endpoint.url())
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.setBasicAuth(username: endpoint.username, password: endpoint.password)
        request.httpBody = xml.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.connectionFailed("No response") }
        if http.statusCode == 401 { throw BackendError.authenticationFailed }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpStatus(http.statusCode) }

        // XML-RPC reports failures as HTTP 200 with a <fault> body.
        let body = String(data: data, encoding: .utf8) ?? ""
        if body.contains("<fault>") {
            throw BackendError.serverError(Self.faultString(in: body))
        }
    }

    private static func faultString(in body: String) -> String {
        guard let r = body.range(of: "faultString"),
              let open = body.range(of: "<string>", range: r.upperBound..<body.endIndex),
              let close = body.range(of: "</string>", range: open.upperBound..<body.endIndex) else {
            return "rTorrent reported an error"
        }
        return String(body[open.upperBound..<close.lowerBound])
    }
}
