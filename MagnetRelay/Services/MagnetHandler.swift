import Foundation

final class MagnetHandler {
    private let config: ServerConfig
    private let recent: RecentMagnets
    private let notifier: Notifying
    private let clientFactory: (ClientType) -> RemoteClient
    private let openSettings: () -> Void

    init(config: ServerConfig = .shared,
         recent: RecentMagnets = .shared,
         notifier: Notifying,
         clientFactory: @escaping (ClientType) -> RemoteClient = { BackendFactory.create(for: $0) },
         openSettings: @escaping () -> Void) {
        self.config = config
        self.recent = recent
        self.notifier = notifier
        self.clientFactory = clientFactory
        self.openSettings = openSettings
    }

    func handleMagnet(_ magnetURL: String) async {
        let magnet = magnetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MagnetLink.isMagnet(magnet) else { return }

        // Capture everything up front so a settings change mid-send can't mislabel the result.
        let client = config.clientType
        guard config.isConfigured, let endpoint = config.endpoint() else {
            await notifier.post(title: "MagnetRelay", body: "Set up MagnetRelay to start sending links.")
            await MainActor.run { openSettings() }
            return
        }
        let host = endpoint.baseURL.host
        let notifyOnSuccess = config.showNotifications
        let backend = clientFactory(client)

        do {
            try await BackendSession.withRetry {
                try await backend.addMagnet(magnet, to: endpoint)
            }
            await MainActor.run { recent.add(magnet) }
            if notifyOnSuccess {
                await notifier.post(title: "Sent to \(client.displayName)", body: MagnetLink.displayName(from: magnet))
            }
        } catch {
            await notifier.post(title: "Couldn't send link", body: ConnectionError.message(for: error, client: client, host: host))
        }
    }
}
