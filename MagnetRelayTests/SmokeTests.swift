import XCTest

final class SmokeTests: XCTestCase {
    override func setUp() { StubURLProtocol.reset() }

    func testStubRecordsBody() async throws {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        var req = URLRequest(url: URL(string: "http://example.test/x")!)
        req.httpMethod = "POST"
        req.httpBody = Data("a=1".utf8)
        _ = try await StubURLProtocol.session().data(for: req)
        XCTAssertEqual(StubURLProtocol.requests.first?.bodyString, "a=1")
    }
}
