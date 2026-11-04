import XCTest
@testable import MagnetRelay

final class FakePasswordStore: PasswordStoring {
    var stored: String?
    func password() -> String? { stored }
    @discardableResult func setPassword(_ p: String) -> Bool { stored = p; return true }
}

final class HTTPTests: XCTestCase {
    private func draft(host: String = "nas", port: String = "8080", https: Bool = false, path: String = "") -> ConnectionDraft {
        ConnectionDraft(clientType: .qbittorrent, host: host, port: port, useHTTPS: https,
                        path: path, username: "u", password: "p")
    }

    func testFormEncodingEscapesReserved() {
        let out = FormEncoding.encode([("urls", "magnet:?xt=urn:btih:AB&dn=a b+c&tr=udp://t:1/x")])
        XCTAssertEqual(out, "urls=magnet%3A%3Fxt%3Durn%3Abtih%3AAB%26dn%3Da%20b%2Bc%26tr%3Dudp%3A%2F%2Ft%3A1%2Fx")
    }

    func testFormEncodingPassword() {
        XCTAssertEqual(FormEncoding.encode([("username", "me"), ("password", "p&s=+w")]),
                       "username=me&password=p%26s%3D%2Bw")
    }

    func testPathJoining() {
        for p in ["RPC2", "/RPC2", "/RPC2/"] {
            XCTAssertEqual(draft(path: p).endpoint()!.url().absoluteString, "http://nas:8080/RPC2", p)
        }
        XCTAssertEqual(draft(path: "/qbt/").endpoint()!.url("api", "v2").absoluteString, "http://nas:8080/qbt/api/v2")
        XCTAssertEqual(draft(path: "").endpoint()!.url("json").absoluteString, "http://nas:8080/json")
    }

    func testHostNormalisation() {
        XCTAssertEqual(draft(host: " http://nas.local:9091/ ", port: "8080").endpoint()!.baseURL.absoluteString,
                       "http://nas.local:9091")
        XCTAssertEqual(draft(host: "https://box", port: "5001").endpoint()!.baseURL.absoluteString,
                       "https://box:5001")
        XCTAssertNil(draft(host: "").endpoint())
    }

    func testHostWithoutSchemeButPort() {
        XCTAssertEqual(draft(host: "nas:9091", port: "8080").endpoint()!.baseURL.absoluteString, "http://nas:9091")
        XCTAssertEqual(draft(host: "nas/qbt", port: "8080", https: true).endpoint()!.baseURL.absoluteString,
                       "https://nas:8080/qbt")
        XCTAssertEqual(draft(host: "192.168.0.100", port: "8080").endpoint()!.baseURL.absoluteString,
                       "http://192.168.0.100:8080")
    }

    func testHTTPSFlag() {
        XCTAssertEqual(draft(https: true).endpoint() == nil, false)
        XCTAssertEqual(draft(port: "5001", https: true).endpoint()!.baseURL.absoluteString, "https://nas:5001")
    }

    func testDefaultPorts() {
        XCTAssertEqual(ClientType.synology.defaultPort(https: true), "5001")
        XCTAssertEqual(ClientType.synology.defaultPort(https: false), "5000")
        XCTAssertEqual(ClientType.qbittorrent.defaultPort(https: true), "8080")
    }

    func testConfigApplyRoundTrip() {
        let suite = "MagnetRelayTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fake = FakePasswordStore()
        let config = ServerConfig(store: defaults, passwords: fake)
        XCTAssertFalse(config.isConfigured)
        let d = ConnectionDraft(clientType: .rtorrent, host: "nas", port: "8080", useHTTPS: true,
                                path: "RPC2", username: "me", password: "secret")
        config.apply(d)
        XCTAssertEqual(config.draft(), d)
        XCTAssertEqual(fake.stored, "secret")
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.endpoint()?.url().absoluteString, "https://nas:8080/RPC2")
    }
}
