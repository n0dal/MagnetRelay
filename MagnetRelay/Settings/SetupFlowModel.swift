import Foundation

/// Drives the three setup steps (client, address, sign in). Edits a draft; see spec section 4.1.
@MainActor
final class SetupFlowModel: ObservableObject {
    enum Step: Int { case client = 1, address, signIn }
    enum Mode { case firstRun, changeServer }
    enum Outcome { case connected, cancelled }

    @Published var step: Step = .client
    @Published var draft: ConnectionDraft
    @Published private(set) var isConnecting = false
    @Published private(set) var errorMessage: String?
    @Published var showsPath: Bool

    var onFinish: (Outcome) -> Void = { _ in }

    /// Editing a draft of a working config (step 1's left button is Cancel).
    var isChangingServer: Bool { mode == .changeServer }

    private let mode: Mode
    private let config: ServerConfig
    private let clientFactory: (ClientType) -> RemoteClient
    private var connectTask: Task<Void, Error>?

    init(mode: Mode, config: ServerConfig, clientFactory: @escaping (ClientType) -> RemoteClient) {
        self.mode = mode
        self.config = config
        self.clientFactory = clientFactory
        let d = config.draft()
        self.draft = d
        self.showsPath = !d.path.trimmed.isEmpty
    }

    // MARK: Editing

    private func isDefaultPort(_ port: String) -> Bool {
        let p = port.trimmed
        if p.isEmpty { return true }
        return ClientType.allCases.contains { c in
            p == c.defaultPort(https: true) || p == c.defaultPort(https: false)
        }
    }

    func selectClient(_ c: ClientType) {
        let wasDefault = isDefaultPort(draft.port)
        draft.clientType = c
        if c == .synology { draft.useHTTPS = true }
        if wasDefault { draft.port = c.defaultPort(https: draft.useHTTPS) }
        if c == .rtorrent {
            if draft.path.trimmed.isEmpty { draft.path = "/RPC2" }
            showsPath = true
        }
        errorMessage = nil
    }

    func setHTTPS(_ on: Bool) {
        let wasDefault = isDefaultPort(draft.port)
        draft.useHTTPS = on
        if wasDefault { draft.port = draft.clientType.defaultPort(https: on) }
    }

    // MARK: Navigation

    var canContinue: Bool {
        switch step {
        case .client: return true
        case .address: return draft.endpoint() != nil
        case .signIn:
            if isConnecting { return false }
            return draft.clientType == .deluge || !draft.username.trimmed.isEmpty
        }
    }

    func next() {
        switch step {
        case .client: step = .address
        case .address: step = .signIn
        case .signIn: return
        }
        if mode == .firstRun { config.apply(draft, savePassword: false) }
    }

    func back() {
        switch step {
        case .client:
            if mode == .changeServer { onFinish(.cancelled) }
        case .address: step = .client
        case .signIn: step = .address
        }
    }

    // MARK: Connect

    func connect() async {
        guard !isConnecting, let endpoint = draft.endpoint() else { return }
        errorMessage = nil
        isConnecting = true
        let client = clientFactory(draft.clientType)
        let task = Task { try await client.testConnection(endpoint) }
        connectTask = task
        do {
            try await task.value
            guard connectTask == task else { return }
            connectTask = nil
            isConnecting = false
            guard config.apply(draft) else {
                errorMessage = "Couldn't save your password to the Keychain. Try again."
                return
            }
            config.markConfigAsTested()
            config.hasCompletedSetup = true
            onFinish(.connected)
        } catch {
            // A cancelled attempt (or a superseded one) shows nothing.
            guard !task.isCancelled, connectTask == task else { return }
            connectTask = nil
            isConnecting = false
            errorMessage = ConnectionError.message(for: error, client: draft.clientType)
        }
    }

    func cancelConnect() {
        connectTask?.cancel()
        connectTask = nil
        isConnecting = false
    }
}
