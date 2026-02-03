import Foundation
import UserNotifications

class MagnetHandler {
    private let config = ServerConfig.shared

    func handleMagnet(_ magnetURL: String) async {
        guard !config.serverURL.isEmpty else {
            await showNotification(
                title: "Magnet Remote",
                body: "No server configured. Open Settings to set up.",
                isError: true
            )
            return
        }

        let backend = BackendFactory.create(for: config.clientType)
        let password = KeychainService.getPassword() ?? ""

        do {
            try await backend.addMagnet(
                magnetURL,
                url: config.serverURL,
                username: config.username,
                password: password
            )

            await showNotification(
                title: "Torrent Added",
                body: "Sent to \(config.clientType.displayName)",
                isError: false
            )
        } catch {
            await showNotification(
                title: "Failed to Add Torrent",
                body: error.localizedDescription,
                isError: true
            )
        }
    }

    func testConnection() async {
        guard !config.serverURL.isEmpty else {
            await showNotification(
                title: "Test Failed",
                body: "No server URL configured",
                isError: true
            )
            return
        }

        let backend = BackendFactory.create(for: config.clientType)
        let password = KeychainService.getPassword() ?? ""

        do {
            try await backend.testConnection(
                url: config.serverURL,
                username: config.username,
                password: password
            )

            await showNotification(
                title: "Connection Successful",
                body: "Connected to \(config.clientType.displayName)",
                isError: false
            )
        } catch {
            await showNotification(
                title: "Connection Failed",
                body: error.localizedDescription,
                isError: true
            )
        }
    }

    private func showNotification(title: String, body: String, isError: Bool) async {
        guard config.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isError ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
