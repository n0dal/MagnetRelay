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
            // Use retry logic for transient failures
            try await BackendSession.withRetry {
                try await backend.addMagnet(
                    magnetURL,
                    url: config.serverURL,
                    username: config.username,
                    password: password
                )
            }

            // Save to recent magnets on success
            RecentMagnets.shared.add(magnetURL)

            await showNotification(
                title: "Magnet Sent",
                body: "Sent to \(config.clientType.displayName)",
                isError: false
            )
        } catch {
            // Use user-friendly error message
            let friendlyMessage = ConnectionError.userFriendlyMessage(from: error)
            await showNotification(
                title: "Failed to Send",
                body: friendlyMessage,
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
