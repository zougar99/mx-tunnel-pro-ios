import NetworkExtension
import Foundation

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let config = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = config.providerConfiguration else {
            completionHandler(PacketTunnelError.noConfiguration)
            return
        }

        guard let protoString = providerConfig["protocolType"] as? String,
              let proto = TunnelProtocol(rawValue: protoString) else {
            completionHandler(PacketTunnelError.invalidProtocol)
            return
        }

        let serverAddress = providerConfig["serverAddress"] as? String ?? ""
        let serverPort = providerConfig["serverPort"] as? UInt16 ?? 443

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dns.matchDomains = [""]
        networkSettings.dnsSettings = dns

        networkSettings.mtu = 1500

        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                completionHandler(error)
                return
            }

            switch proto {
            case .http:
                self.startHTTPTunnel(config: providerConfig, completionHandler: completionHandler)
            case .ssh:
                self.startSSHTunnel(config: providerConfig, completionHandler: completionHandler)
            case .vmess, .vless:
                self.startV2RayTunnel(config: providerConfig, completionHandler: completionHandler)
            case .shadowsocks:
                self.startShadowsocksTunnel(config: providerConfig, completionHandler: completionHandler)
            case .wireGuard:
                self.startWireGuardTunnel(config: providerConfig, completionHandler: completionHandler)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }

    private func startHTTPTunnel(config: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let host = config["serverAddress"] as? String ?? ""
        let port = config["serverPort"] as? UInt16 ?? 8080
        let username = config["username"] as? String ?? ""
        let password = config["password"] as? String ?? ""

        let httpHandler = HTTPConnectHandler(
            packetTunnelProvider: self,
            serverHost: host,
            serverPort: Int(port),
            username: username,
            password: password
        )
        httpHandler.start(completionHandler: completionHandler)
    }

    private func startSSHTunnel(config: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let host = config["serverAddress"] as? String ?? ""
        let port = config["serverPort"] as? UInt16 ?? 22
        let username = config["username"] as? String ?? ""
        let password = config["password"] as? String ?? ""

        let sshHandler = SSHTunnelHandler(
            packetTunnelProvider: self,
            serverHost: host,
            serverPort: Int(port),
            username: username,
            password: password
        )
        sshHandler.start(completionHandler: completionHandler)
    }

    private func startV2RayTunnel(config: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let host = config["serverAddress"] as? String ?? ""
        let port = config["serverPort"] as? UInt16 ?? 443
        let uuid = config["uuid"] as? String ?? ""
        let security = config["security"] as? String ?? "tls"
        let sni = config["sni"] as? String ?? ""
        let transport = config["transportType"] as? String ?? "tcp"

        let v2rayHandler = V2RayHandler(
            packetTunnelProvider: self,
            serverHost: host,
            serverPort: Int(port),
            uuid: uuid,
            security: security,
            sni: sni,
            transport: transport
        )
        v2rayHandler.start(completionHandler: completionHandler)
    }

    private func startShadowsocksTunnel(config: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let host = config["serverAddress"] as? String ?? ""
        let port = config["serverPort"] as? UInt16 ?? 8388
        let password = config["password"] as? String ?? ""
        let method = config["security"] as? String ?? "aes-256-gcm"

        let ssHandler = ShadowsocksHandler(
            packetTunnelProvider: self,
            serverHost: host,
            serverPort: Int(port),
            password: password,
            encryptionMethod: method
        )
        ssHandler.start(completionHandler: completionHandler)
    }

    private func startWireGuardTunnel(config: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let host = config["serverAddress"] as? String ?? ""
        let port = config["serverPort"] as? UInt16 ?? 51820
        let privateKey = config["password"] as? String ?? ""
        let publicKey = config["uuid"] as? String ?? ""

        let wgHandler = WireGuardHandler(
            packetTunnelProvider: self,
            serverHost: host,
            serverPort: Int(port),
            privateKey: privateKey,
            publicKey: publicKey
        )
        wgHandler.start(completionHandler: completionHandler)
    }
}

enum PacketTunnelError: Error, LocalizedError {
    case noConfiguration
    case invalidProtocol
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noConfiguration: return "No configuration found"
        case .invalidProtocol: return "Invalid protocol type"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        }
    }
}
