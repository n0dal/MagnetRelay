import XCTest
@testable import MagnetRelay

final class MagnetLinkTests: XCTestCase {
    func testIsMagnet() {
        XCTAssertTrue(MagnetLink.isMagnet("MAGNET:?xt=urn:btih:AB"))
        XCTAssertFalse(MagnetLink.isMagnet("https://x"))
        XCTAssertFalse(MagnetLink.isMagnet("magnet:?dn=x"))
    }

    func testDisplayNameUsesDn() {
        XCTAssertEqual(MagnetLink.displayName(from: "magnet:?xt=urn:btih:0123456789&dn=Ubuntu+24.04"), "Ubuntu 24.04")
    }

    func testDisplayNameFallsBackToHash() {
        XCTAssertEqual(MagnetLink.displayName(from: "magnet:?xt=urn:btih:0123456789"), "01234567…")
    }

    func testDisplayNameUnknown() {
        XCTAssertEqual(MagnetLink.displayName(from: "nonsense"), "Unknown link")
    }

    func testDisplayNameTruncates() {
        let dn = String(repeating: "a", count: 60)
        let out = MagnetLink.displayName(from: "magnet:?xt=urn:btih:AB&dn=\(dn)")
        XCTAssertEqual(out.count, 45)
        XCTAssertTrue(out.hasSuffix("…"))
    }
}
