import XCTest
@testable import MagnetRelay

final class FlowClient: RemoteClient {
    var error: Error?
    var hangs = false
    func testConnection(_ endpoint: ServerEndpoint) async throws {
        if hangs { try await Task.sleep(nanoseconds: 60_000_000_000) }
        if let error { throw error }
    }
    func addMagnet(_ magnet: String, to endpoint: ServerEndpoint) async throws {}
}

@MainActor
final class SetupFlowModelTests: XCTestCase {
    var config: ServerConfig!
    var passwords: FakePasswordStore!
    var client: FlowClient!
    var outcomes: [SetupFlowModel.Outcome] = []

    override func setUp() {
        passwords = FakePasswordStore()
        client = FlowClient()
        outcomes = []
        config = ServerConfig(store: UserDefaults(suiteName: "SetupFlowTests-\(UUID().uuidString)")!, passwords: passwords)
    }

    private func model(_ mode: SetupFlowModel.Mode) -> SetupFlowModel {
        let m = SetupFlowModel(mode: mode, config: config, clientFactory: { _ in self.client })
        m.onFinish = { self.outcomes.append($0) }
        return m
    }

    func testFirstRunPersistsAsYouGo() {
        let m = model(.firstRun)
        m.selectClient(.transmission)
        m.next()
        XCTAssertEqual(m.step, .address)
        XCTAssertEqual(config.clientType, .transmission)
        m.draft.host = "nas"
        m.draft.password = "secret"
        m.next()
        XCTAssertEqual(config.serverHost, "nas")
        XCTAssertNil(passwords.stored)
        XCTAssertFalse(config.hasCompletedSetup)
    }

    func testChangeServerDoesNotTouchLiveConfigUntilConnect() async {
        config.serverHost = "old"
        config.serverPort = "8080"
        let m = model(.changeServer)
        m.draft.host = "other"
        m.next(); m.next()
        XCTAssertEqual(config.serverHost, "old")
        m.draft.username = "u"
        m.draft.password = "p"
        await m.connect()
        XCTAssertEqual(config.serverHost, "other")
        XCTAssertEqual(passwords.stored, "p")
        XCTAssertTrue(config.hasCompletedSetup)
        XCTAssertEqual(outcomes, [.connected])
    }

    func testChangeServerCancelFromStepOne() {
        let m = model(.changeServer)
        m.back()
        XCTAssertEqual(outcomes, [.cancelled])
    }

    func testPortSwapsOnlyWhenDefault() {
        let m = model(.firstRun)
        m.draft.port = "8080"
        m.selectClient(.transmission)
        XCTAssertEqual(m.draft.port, "9091")
        m.draft.port = "1234"
        m.selectClient(.deluge)
        XCTAssertEqual(m.draft.port, "1234")
    }

    func testRTorrentPrefillsRPC2() {
        let m = model(.firstRun)
        m.selectClient(.rtorrent)
        XCTAssertEqual(m.draft.path, "/RPC2")
        XCTAssertTrue(m.showsPath)
    }

    func testSynologyDefaultsHTTPS5001() {
        let m = model(.firstRun)
        m.selectClient(.synology)
        XCTAssertTrue(m.draft.useHTTPS)
        XCTAssertEqual(m.draft.port, "5001")
        m.setHTTPS(false)
        XCTAssertEqual(m.draft.port, "5000")
        m.setHTTPS(true)
        XCTAssertEqual(m.draft.port, "5001")
    }

    func testConnectFailureShowsMessageAndStays() async {
        client.error = BackendError.authenticationFailed
        let m = model(.firstRun)
        m.draft.host = "nas"; m.draft.username = "u"
        m.step = .signIn
        await m.connect()
        XCTAssertNotNil(m.errorMessage)
        XCTAssertEqual(m.step, .signIn)
        XCTAssertFalse(m.isConnecting)
        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertFalse(config.hasCompletedSetup)
    }

    func testCancelConnectShowsNoError() async {
        client.hangs = true
        let m = model(.firstRun)
        m.draft.host = "nas"; m.draft.username = "u"
        m.step = .signIn
        let task = Task { await m.connect() }
        while !m.isConnecting { await Task.yield() }
        m.cancelConnect()
        XCTAssertFalse(m.isConnecting)
        await task.value
        XCTAssertNil(m.errorMessage)
        XCTAssertTrue(outcomes.isEmpty)
    }

    func testDelugeNeedsNoUsername() {
        let m = model(.firstRun)
        m.draft.host = "nas"
        m.step = .signIn
        m.draft.clientType = .qbittorrent
        XCTAssertFalse(m.canContinue)
        m.draft.clientType = .deluge
        XCTAssertTrue(m.canContinue)
    }

    func testCancelAfterSuccessBeforeResumeDoesNotApply() async {
        config.serverHost = "old"
        let m = model(.changeServer)
        m.draft.host = "other"; m.draft.username = "u"
        m.step = .signIn
        let task = Task { await m.connect() }
        while !m.isConnecting { await Task.yield() }
        m.cancelConnect()   // client returns immediately and ignores cancellation
        await task.value
        XCTAssertEqual(config.serverHost, "old")
        XCTAssertFalse(config.hasCompletedSetup)
        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertNil(m.errorMessage)
    }
}
