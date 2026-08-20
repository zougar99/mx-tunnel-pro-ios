import Foundation
import NetworkExtension
import Combine

enum VPNStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case disconnecting = "Disconnecting..."
    case invalid = "Invalid"

    var color: String {
        switch self {
        case .connected: return "green"
        case .connecting, .disconnecting: return "yellow"
        case .disconnected, .invalid: return "red"
        }
    }

    init(from status: NEVPNStatus) {
        switch status {
        case .disconnected: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .disconnecting: self = .disconnecting
        case .invalid: self = .invalid
        case .reasserting: self = .connecting
        @unknown default: self = .disconnected
        }
    }
}

class VPNManager: ObservableObject {
    @Published var status: VPNStatus = .disconnected
    @Published var bytesIn: Int64 = 0
    @Published var bytesOut: Int64 = 0
    @Published var connectionStartTime: Date?

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private let tunnelBundleID = "com.mxtunnel.pro.PacketTunnel"

    init() {
        loadManager()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var connectionDuration: String {
        guard let start = connectionStartTime else { return "00:00:00" }
        let elapsed = Date().timeIntervalSince(start)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            DispatchQueue.main.async {
                if let managers = managers, !managers.isEmpty {
                    self.tunnelManager = managers.first
                } else {
                    self.tunnelManager = NETunnelProviderManager()
                }
                self.updateStatus()
            }
        }
    }

    func connect(config: ServerConfig) {
        guard let manager = tunnelManager else {
            loadManager()
            return
        }

        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = tunnelBundleID
        providerProtocol.serverAddress = "\(config.serverAddress):\(config.serverPort)"
        providerProtocol.providerConfiguration = config.toDictionary() as? [String: NSObject]

        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = "MxTunnelPro VPN"
        manager.isEnabled = true

        manager.saveToPreferences { error in
            if let error = error {
                print("Save error: \(error.localizedDescription)")
                return
            }
            manager.loadFromPreferences { error in
                if let error = error {
                    print("Load error: \(error.localizedDescription)")
                    return
                }
                do {
                    try manager.connection.startVPNTunnel(options: [
                        "activationAttemptId": UUID().uuidString as NSObject
                    ])
                    DispatchQueue.main.async {
                        self.status = .connecting
                        self.connectionStartTime = Date()
                    }
                } catch {
                    print("Start error: \(error.localizedDescription)")
                }
            }
        }
    }

    func disconnect() {
        tunnelManager?.connection.stopVPNTunnel()
        DispatchQueue.main.async {
            self.status = .disconnecting
        }
    }

    func toggle(config: ServerConfig) {
        if status == .connected || status == .connecting {
            disconnect()
        } else {
            connect(config: config)
        }
    }

    @objc private func vpnStatusDidChange() {
        updateStatus()
    }

    private func updateStatus() {
        DispatchQueue.main.async {
            if let manager = self.tunnelManager {
                self.status = VPNStatus(from: manager.connection.status)
            }
        }
    }
}
