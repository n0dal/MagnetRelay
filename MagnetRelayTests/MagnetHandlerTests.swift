import XCTest
@testable import MagnetRelay

final class FakeNotifier: Notifying {
    var posts: [(title: String, body: String)] = []
    func post(title: String, body: String) async { posts.append((title, body)) }
}

final class FakeClient: RemoteClient {
    var error: Error?
    var sent: [String] = []
    func testConnection(_ endpoint: ServerEndpoint) async throws {}
    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {
        if let error { throw error }
        sent.append(magnet)
    }
}

final class MagnetHandlerTests: XCTestCase {
    let magnet = "magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Ubuntu+24.04"
    var notifier: FakeNotifier!
    var client: FakeClient!
    var config: ServerConfig!
    var recent: RecentMagnets!
    var settingsOpened = 0

    override func setUp() {
        notifier = FakeNotifier()
        client = FakeClient()
        settingsOpened = 0
        let suite = "MagnetHandlerTests-\(UUID().uuidString)"
        config = ServerConfig(store: UserDefaults(suiteName: suite)!, passwords: FakePasswordStore())
        recent = RecentMagnets(defaults: UserDefaults(suiteName: suite + "-r")!)
    }

    private func configure() {
        config.clientType = .transmission
        config.serverHost = "nas"
        config.serverPort = "9091"
    }

    private func handler() -> MagnetHandler {
        MagnetHandler(config: config, recent: recent, notifier: notifier,
                      clientFactory: { _ in self.client }, openSettings: { self.settingsOpened += 1 })
    }

    func testIgnoresNonMagnet() async {
        configure()
        await handler().handleMagnet("https://example.com")
        XCTAssertTrue(notifier.posts.isEmpty)
        XCTAssertTrue(client.sent.isEmpty)
        XCTAssertEqual(settingsOpened, 0)
    }

    func testNotConfiguredOpensSettings() async {
        await handler().handleMagnet(magnet)
        XCTAssertEqual(settingsOpened, 1)
        XCTAssertEqual(notifier.posts.count, 1)
        XCTAssertEqual(notifier.posts[0].title, "MagnetRelay")
        XCTAssertEqual(notifier.posts[0].body, "Set up MagnetRelay to start sending links.")
        XCTAssertTrue(client.sent.isEmpty)
    }

    func testSuccessAddsRecentAndNotifies() async {
        configure()
        config.showNotifications = true
        await handler().handleMagnet(magnet)
        XCTAssertEqual(client.sent, [magnet])
        XCTAssertEqual(recent.items.map(\.magnetURL), [magnet])
        XCTAssertEqual(notifier.posts.count, 1)
        XCTAssertEqual(notifier.posts[0].title, "Sent to \(ClientType.transmission.displayName)")
        XCTAssertEqual(notifier.posts[0].body, "Ubuntu 24.04")
    }

    func testSuccessSilentWhenNotificationsOff() async {
        configure()
        config.showNotifications = false
        await handler().handleMagnet(magnet)
        XCTAssertEqual(recent.items.count, 1)
        XCTAssertTrue(notifier.posts.isEmpty)
    }

    func testFailureNotifiesEvenWhenSuccessNotificationsOff() async {
        configure()
        config.showNotifications = false
        client.error = BackendError.authenticationFailed
        await handler().handleMagnet(magnet)
        XCTAssertTrue(recent.items.isEmpty)
        XCTAssertEqual(notifier.posts.count, 1)
        XCTAssertEqual(notifier.posts[0].title, "Couldn't send link")
        XCTAssertEqual(notifier.posts[0].body,
                       ConnectionError.message(for: BackendError.authenticationFailed, client: .transmission))
    }
}
