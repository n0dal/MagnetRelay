import XCTest
@testable import MagnetRelay

final class NetworkAddressTests: XCTestCase {
    func testLocal() {
        for h in ["localhost", "NAS.local", "10.0.0.2", "172.20.1.1", "192.168.0.100", "127.0.0.1",
                  "169.254.1.1", "::1", "fe80::1", "[::1]", "diskstation", "nas"] {
            XCTAssertTrue(NetworkAddress.isLocal(host: h), h)
        }
        for h in ["172.32.0.1", "8.8.8.8", "example.com", "nas.example.com", "172.15.0.1", "192.169.0.1"] {
            XCTAssertFalse(NetworkAddress.isLocal(host: h), h)
        }
    }
}
