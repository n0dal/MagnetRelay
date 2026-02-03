import SwiftUI

@main
struct MagnetRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app - settings window managed by AppDelegate
        // Using WindowGroup with commands disabled to prevent SwiftUI from
        // creating unwanted windows while still satisfying the Scene requirement
        WindowGroup {
            Color.clear
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}
