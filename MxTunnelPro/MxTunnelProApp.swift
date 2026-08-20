import SwiftUI

@main
struct MxTunnelProApp: App {
    @StateObject private var vpnManager = VPNManager()
    @StateObject private var configManager = ConfigManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
                .environmentObject(configManager)
        }
    }
}
