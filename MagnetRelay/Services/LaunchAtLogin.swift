import Foundation
import ServiceManagement

/// Launch-at-login state, read from the system rather than stored locally.
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled: Bool

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters, then re-reads the real status so a failure reverts the switch.
    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Fall through: the status re-read below reflects what actually happened.
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
