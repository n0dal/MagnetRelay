import XCTest
@testable import MagnetRelay

final class ConnectionErrorTests: XCTestCase {
    private func msg(_ e: Error) -> String { ConnectionError.message(for: e, client: .qbittorrent) }

    func testMessages() {
        let c = ClientType.qbittorrent.displayName
        let cert = "The server's certificate isn't trusted by this Mac. Use a trusted certificate, or HTTPS may not be set up on this port."
        let timeout = "\(c) didn't answer in time. Check that it's running and reachable from this Mac."
        XCTAssertEqual(msg(URLError(.cannotConnectToHost)), "Couldn't reach \(c). Check the address and port, and that it's running.")
        XCTAssertEqual(msg(URLError(.cannotFindHost)), "Couldn't find that address. Check it for typos.")
        XCTAssertEqual(msg(URLError(.timedOut)), timeout)
        XCTAssertEqual(msg(URLError(.serverCertificateUntrusted)), cert)
        XCTAssertEqual(msg(URLError(.serverCertificateHasUnknownRoot)), cert)
        XCTAssertEqual(msg(URLError(.secureConnectionFailed)), cert)
        XCTAssertEqual(msg(URLError(.appTransportSecurityRequiresSecureConnection)),
                       "This address needs HTTPS. Turn on Use HTTPS, or use the server's local IP address.")
        XCTAssertEqual(msg(URLError(.notConnectedToInternet)), "This Mac isn't connected to a network.")
        XCTAssertEqual(msg(BackendError.authenticationFailed), "\(c) said the username or password is wrong. Check them on its web page and try again.")
        XCTAssertEqual(msg(BackendError.insecureConnection), "Synology needs HTTPS for addresses outside your home network.")
        XCTAssertEqual(msg(BackendError.daemonNotConnected), "Deluge's web page isn't connected to Deluge. Open it in a browser and connect to a host first.")
        XCTAssertEqual(msg(BackendError.httpStatus(404)), "\(c) isn't at that address. Check the port and path.")
        XCTAssertEqual(msg(BackendError.httpStatus(403)), "\(c) refused the connection. Check its web UI security settings.")
        XCTAssertEqual(msg(BackendError.serverError("x")), "\(c) couldn't add the link: x")
        XCTAssertEqual(msg(BackendError.invalidURL), "That address doesn't look right. Check it for typos.")
        XCTAssertEqual(msg(BackendError.connectionFailed("x")), "Couldn't reach \(c): x")
        struct E: LocalizedError { var errorDescription: String? { "boom" } }
        XCTAssertEqual(msg(E()), "Something went wrong: boom")
    }

    func testSynologyLocalCertificateMessage() {
        let local = "Your Synology's certificate isn't trusted by this Mac. On your home network you can turn off Use HTTPS, or install a trusted certificate on the Synology."
        let cert = "The server's certificate isn't trusted by this Mac. Use a trusted certificate, or HTTPS may not be set up on this port."
        for code in [URLError.Code.serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .secureConnectionFailed] {
            XCTAssertEqual(ConnectionError.message(for: URLError(code), client: .synology, host: "192.168.1.5"), local)
            XCTAssertEqual(ConnectionError.message(for: URLError(code), client: .synology, host: "nas.local"), local)
            XCTAssertEqual(ConnectionError.message(for: URLError(code), client: .synology, host: "example.com"), cert)
            XCTAssertEqual(ConnectionError.message(for: URLError(code), client: .synology), cert)
            XCTAssertEqual(ConnectionError.message(for: URLError(code), client: .qbittorrent, host: "192.168.1.5"), cert)
        }
    }
}
