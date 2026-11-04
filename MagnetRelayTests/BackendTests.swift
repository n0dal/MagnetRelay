import XCTest
@testable import MagnetRelay

final class BackendTests: XCTestCase {
    let M = "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Ubuntu%2024.04&tr=udp%3A%2F%2Ft.example%3A1337"
    let M2 = "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Caf%C3%A9%20%F0%9F%8E%B5&tr=udp%3A%2F%2Ft.example%3A1337&tr=http%3A%2F%2Fb.example%2Fa%3Fx%3D1%26y%3D2&x.pe=1.2.3.4:5+6"

    override func setUp() { StubURLProtocol.reset() }
    override func tearDown() { StubURLProtocol.reset() }

    private func endpoint(host: String = "nas", port: String = "8080", https: Bool = false, path: String = "",
                          user: String = "admin", pass: String = "p&w") -> ServerEndpoint {
        ConnectionDraft(clientType: .qbittorrent, host: host, port: port, useHTTPS: https, path: path,
                        username: user, password: pass).endpoint()!
    }

    private func response(_ req: URLRequest, _ body: String, status: Int = 200, headers: [String: String] = [:]) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, Data(body.utf8))
    }

    private func json(_ req: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any]) ?? [:]
    }

    private func formValue(_ body: String, _ key: String) -> String? {
        for pair in body.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0].removingPercentEncoding == key { return kv[1].removingPercentEncoding }
        }
        return nil
    }

    // MARK: qBittorrent

    func testQBittorrentLoginAndAdd() async throws {
        StubURLProtocol.handler = { req in
            if req.url!.path == "/api/v2/auth/login" {
                return self.response(req, "Ok.", headers: ["Set-Cookie": "SID=abc; path=/"])
            }
            return self.response(req, "Ok.")
        }
        try await QBittorrentBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint())
        let reqs = StubURLProtocol.requests
        XCTAssertEqual(reqs.count, 2)
        XCTAssertEqual(reqs[0].httpMethod, "POST")
        XCTAssertEqual(reqs[0].url!.absoluteString, "http://nas:8080/api/v2/auth/login")
        XCTAssertEqual(reqs[0].bodyString, "username=admin&password=p%26w")
        XCTAssertEqual(reqs[1].url!.absoluteString, "http://nas:8080/api/v2/torrents/add")
        XCTAssertEqual(reqs[1].value(forHTTPHeaderField: "Cookie"), "SID=abc")
        XCTAssertEqual(reqs[1].bodyString, FormEncoding.encode([("urls", M)]))
    }

    func testQBittorrentBadLoginThrowsAuth() async {
        StubURLProtocol.handler = { self.response($0, "Fails.") }
        do {
            try await QBittorrentBackend(session: StubURLProtocol.session()).testConnection(endpoint())
            XCTFail("expected throw")
        } catch BackendError.authenticationFailed {
        } catch { XCTFail("\(error)") }
    }

    // MARK: Transmission

    func testTransmissionSessionHandshake() async throws {
        StubURLProtocol.handler = { req in
            if req.value(forHTTPHeaderField: "X-Transmission-Session-Id") == nil {
                return self.response(req, "", status: 409, headers: ["X-Transmission-Session-Id": "s1"])
            }
            return self.response(req, #"{"result":"success"}"#)
        }
        try await TransmissionBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint())
        let reqs = StubURLProtocol.requests
        XCTAssertEqual(reqs.first?.url?.absoluteString, "http://nas:8080/transmission/rpc")
        let add = reqs.last!
        XCTAssertEqual(add.value(forHTTPHeaderField: "X-Transmission-Session-Id"), "s1")
        XCTAssertEqual((json(add)["arguments"] as? [String: Any])?["filename"] as? String, M)
        XCTAssertNotNil(add.value(forHTTPHeaderField: "Authorization"))
    }

    func testTransmission401ThrowsAuth() async {
        StubURLProtocol.handler = { self.response($0, "", status: 401) }
        do {
            try await TransmissionBackend(session: StubURLProtocol.session()).testConnection(endpoint())
            XCTFail("expected throw")
        } catch BackendError.authenticationFailed {
        } catch { XCTFail("\(error)") }
    }

    // MARK: Deluge

    private func delugeHandler(connected: Bool, hosts: String, methods: @escaping (String) -> Void = { _ in }) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        return { req in
            let method = self.json(req)["method"] as? String ?? ""
            methods(method)
            switch method {
            case "auth.login": return self.response(req, #"{"result":true,"error":null,"id":1}"#, headers: ["Set-Cookie": "_session_id=zz; path=/"])
            case "web.connected": return self.response(req, #"{"result":\#(connected),"error":null,"id":1}"#)
            case "web.get_hosts": return self.response(req, #"{"result":\#(hosts),"error":null,"id":1}"#)
            default: return self.response(req, #"{"result":true,"error":null,"id":1}"#)
            }
        }
    }

    func testDelugeConnectsDaemonWhenNeeded() async throws {
        StubURLProtocol.handler = delugeHandler(connected: false, hosts: #"[["h1","127.0.0.1",58846,"Online"]]"#)
        try await DelugeBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint())
        let reqs = StubURLProtocol.requests
        XCTAssertEqual(reqs.map { self.json($0)["method"] as? String ?? "" },
                       ["auth.login", "web.connected", "web.get_hosts", "web.connect", "core.add_torrent_magnet"])
        XCTAssertEqual(json(reqs[3])["params"] as? [String], ["h1"])
        XCTAssertEqual((json(reqs[4])["params"] as? [Any])?.first as? String, M)
        XCTAssertEqual(reqs[4].value(forHTTPHeaderField: "Cookie"), "_session_id=zz")
    }

    func testDelugeSkipsConnectWhenAlreadyConnected() async throws {
        StubURLProtocol.handler = delugeHandler(connected: true, hosts: "[]")
        try await DelugeBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint())
        XCTAssertEqual(StubURLProtocol.requests.map { self.json($0)["method"] as? String ?? "" },
                       ["auth.login", "web.connected", "core.add_torrent_magnet"])
    }

    func testDelugeNoHostsThrowsDaemonNotConnected() async {
        StubURLProtocol.handler = delugeHandler(connected: false, hosts: "[]")
        do {
            try await DelugeBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint())
            XCTFail("expected throw")
        } catch BackendError.daemonNotConnected {
        } catch { XCTFail("\(error)") }
    }

    // MARK: rTorrent

    func testRTorrentFaultThrows() async {
        StubURLProtocol.handler = { self.response($0, "<methodResponse><fault><value><string>boom</string></value></fault></methodResponse>") }
        do {
            try await RTorrentBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint(path: "/RPC2"))
            XCTFail("expected throw")
        } catch BackendError.serverError {
        } catch { XCTFail("\(error)") }
    }

    func testRTorrentPostsToPath() async throws {
        StubURLProtocol.handler = { self.response($0, "<methodResponse><params/></methodResponse>") }
        try await RTorrentBackend(session: StubURLProtocol.session()).addMagnet(M, to: endpoint(path: "/RPC2"))
        let req = StubURLProtocol.requests[0]
        XCTAssertEqual(req.url!.absoluteString, "http://nas:8080/RPC2")
        XCTAssertTrue(req.bodyString.contains(M.replacingOccurrences(of: "&", with: "&amp;")))
    }

    // MARK: Synology

    func testSynologyRejectsHTTPForPublicHost() async {
        StubURLProtocol.handler = { self.response($0, "{}") }
        do {
            try await SynologyBackend(session: StubURLProtocol.session()).testConnection(endpoint(host: "example.com", port: "5000"))
            XCTFail("expected throw")
        } catch BackendError.insecureConnection {
        } catch { XCTFail("\(error)") }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testSynologyAllowsHTTPOnLAN() async throws {
        StubURLProtocol.handler = { self.response($0, #"{"success":true,"data":{"sid":"S"}}"#) }
        try await SynologyBackend(session: StubURLProtocol.session()).testConnection(endpoint(host: "192.168.1.5", port: "5000"))
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.path, "/webapi/auth.cgi")
    }

    // MARK: Parameter preservation (Review Focus 1)

    private func stubAll() {
        StubURLProtocol.handler = { req in
            let path = req.url!.path
            switch path {
            case "/api/v2/auth/login": return self.response(req, "Ok.", headers: ["Set-Cookie": "SID=abc; path=/"])
            case "/transmission/rpc":
                if req.value(forHTTPHeaderField: "X-Transmission-Session-Id") == nil {
                    return self.response(req, "", status: 409, headers: ["X-Transmission-Session-Id": "s1"])
                }
                return self.response(req, #"{"result":"success"}"#)
            case "/json":
                let m = self.json(req)["method"] as? String ?? ""
                if m == "web.connected" { return self.response(req, #"{"result":true,"error":null}"#) }
                return self.response(req, #"{"result":true,"error":null}"#)
            case "/RPC2": return self.response(req, "<methodResponse><params/></methodResponse>")
            case "/webapi/auth.cgi": return self.response(req, #"{"success":true,"data":{"sid":"S"}}"#)
            default: return self.response(req, #"{"success":true}"#)
            }
        }
    }

    private func received(for type: ClientType, magnet: String) -> [String] {
        let reqs = StubURLProtocol.requests
        switch type {
        case .qbittorrent:
            return reqs.compactMap { $0.url!.path.hasSuffix("torrents/add") ? self.formValue($0.bodyString, "urls") : nil }
        case .transmission:
            return reqs.compactMap { (self.json($0)["arguments"] as? [String: Any])?["filename"] as? String }
        case .deluge:
            return reqs.compactMap { ($0.url!.path == "/json" && self.json($0)["method"] as? String == "core.add_torrent_magnet") ? (self.json($0)["params"] as? [Any])?.first as? String : nil }
        case .rtorrent:
            return reqs.compactMap { r in
                guard let range = r.bodyString.range(of: "<string>magnet:") else { return nil }
                let rest = r.bodyString[range.lowerBound...].dropFirst("<string>".count)
                guard let end = rest.range(of: "</string>") else { return nil }
                return String(rest[..<end.lowerBound]).replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
            }
        case .synology:
            return reqs.compactMap { r in
                guard r.url!.path.hasSuffix("task.cgi"), let q = r.url!.query else { return nil }
                return self.formValue(q, "uri")
            }
        }
    }

    func testAddMagnetPreservesAllParameters() async throws {
        for magnet in [M, M2] {
            for type in ClientType.allCases {
                StubURLProtocol.reset()
                stubAll()
                let ep = type == .synology ? endpoint(host: "192.168.1.5", port: "5000")
                    : endpoint(path: type == .rtorrent ? "/RPC2" : "")
                try await BackendFactory.create(for: type, session: StubURLProtocol.session()).addMagnet(magnet, to: ep)
                XCTAssertEqual(received(for: type, magnet: magnet), [magnet], "\(type) \(magnet)")
            }
        }
    }
}
