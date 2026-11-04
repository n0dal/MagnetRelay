import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum FormEncoding {
    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }

    static func encode(_ pairs: [(String, String)]) -> String {
        pairs.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&")
    }
}

struct ServerEndpoint: Equatable {
    let baseURL: URL
    let username: String
    let password: String

    /// Joins segments onto `baseURL` (including its path) with single slashes.
    func url(_ components: String...) -> URL {
        var parts = baseURL.path.split(separator: "/").map(String.init)
        for c in components { parts += c.split(separator: "/").map(String.init) }
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return baseURL }
        comps.percentEncodedPath = parts.isEmpty ? "" : "/" + parts.map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
        }.joined(separator: "/")
        return comps.url ?? baseURL
    }
}

struct ConnectionDraft: Equatable {
    var clientType: ClientType
    var host: String
    var port: String
    var useHTTPS: Bool
    var path: String
    var username: String
    var password: String

    func endpoint() -> ServerEndpoint? {
        var raw = host.trimmed
        guard !raw.isEmpty else { return nil }
        while raw.hasSuffix("/") { raw.removeLast() }
        guard !raw.isEmpty else { return nil }

        var scheme = useHTTPS ? "https" : "http"
        var hostName = raw
        var portValue = Int(port.trimmed)
        var pathValue = path

        if raw.contains("://") {
            guard let parsed = URLComponents(string: raw), let h = parsed.host, !h.isEmpty,
                  let s = parsed.scheme?.lowercased(), s == "http" || s == "https" else { return nil }
            scheme = s
            hostName = h
            if let p = parsed.port { portValue = p }
            if !parsed.path.trimmed.isEmpty, parsed.path != "/" { pathValue = parsed.path }
        }

        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = hostName
        comps.port = portValue
        let segments = pathValue.split(separator: "/").map(String.init)
        comps.path = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
        guard let url = comps.url, url.host != nil else { return nil }
        return ServerEndpoint(baseURL: url, username: username, password: password)
    }
}

protocol PasswordStoring: AnyObject {
    func password() -> String?
    @discardableResult func setPassword(_ p: String) -> Bool
}

final class KeychainPasswordStore: PasswordStoring {
    func password() -> String? { KeychainService.getPassword() }
    @discardableResult func setPassword(_ p: String) -> Bool {
        KeychainService.setPassword(p)
        return true
    }
}
