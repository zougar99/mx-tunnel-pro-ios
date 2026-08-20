import Foundation
import SwiftUI

class ConfigManager: ObservableObject {
    @Published var servers: [ServerConfig] = []
    @Published var selectedServerId: UUID?

    private let serversKey = "mx_saved_servers"
    private let selectedKey = "mx_selected_server"

    init() {
        loadServers()
    }

    var selectedServer: ServerConfig? {
        servers.first { $0.id == selectedServerId }
    }

    func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: serversKey),
              let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) else {
            servers = [ServerConfig].defaultServers
            return
        }
        servers = decoded
        selectedServerId = UUID(uuidString: UserDefaults.standard.string(forKey: selectedKey) ?? "")
        if selectedServerId == nil {
            selectedServerId = servers.first?.id
        }
    }

    func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: serversKey)
        }
        if let id = selectedServerId {
            UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
        }
    }

    func addServer(_ config: ServerConfig) {
        servers.append(config)
        if servers.count == 1 {
            selectedServerId = config.id
        }
        saveServers()
    }

    func updateServer(_ config: ServerConfig) {
        if let index = servers.firstIndex(where: { $0.id == config.id }) {
            servers[index] = config
            saveServers()
        }
    }

    func deleteServer(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        if let selectedId = selectedServerId, !servers.contains(where: { $0.id == selectedId }) {
            selectedServerId = servers.first?.id
        }
        saveServers()
    }

    func selectServer(_ config: ServerConfig) {
        selectedServerId = config.id
        saveServers()
    }

    func importConfig(from text: String) -> Bool {
        if let data = text.data(using: .utf8),
           let config = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            addServer(config)
            return true
        }
        if let url = URL(string: text), url.scheme == "mxtunnel" {
            return parseMXURL(url)
        }
        return false
    }

    private func parseMXURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        var config = ServerConfig()
        config.name = url.host ?? "Imported"
        for item in components.queryItems ?? [] {
            switch item.name {
            case "addr": config.serverAddress = item.value ?? ""
            case "port": config.serverPort = UInt16(item.value ?? "443") ?? 443
            case "proto": config.protocolType = TunnelProtocol(rawValue: item.value ?? "HTTP") ?? .http
            case "sni": config.sni = item.value ?? ""
            case "user": config.username = item.value ?? ""
            case "pass": config.password = item.value ?? ""
            case "uuid": config.uuid = item.value ?? ""
            default: break
            }
        }
        addServer(config)
        return true
    }

    func exportConfig(_ config: ServerConfig) -> String {
        if let data = try? JSONEncoder().encode(config),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return ""
    }
}

extension [ServerConfig] {
    static var defaultServers: [ServerConfig] {
        [
            ServerConfig(
                name: "HTTP Tunnel",
                protocolType: .http,
                serverPort: 8080,
                security: "none"
            ),
            ServerConfig(
                name: "SSH Tunnel",
                protocolType: .ssh,
                serverPort: 22,
                security: "none"
            ),
            ServerConfig(
                name: "V2Ray Server",
                protocolType: .vmess,
                serverPort: 443,
                transportType: .ws,
                security: "tls"
            ),
            ServerConfig(
                name: "Shadowsocks",
                protocolType: .shadowsocks,
                serverPort: 8388,
                security: "aes-256-gcm"
            ),
            ServerConfig(
                name: "WireGuard",
                protocolType: .wireGuard,
                serverPort: 51820,
                security: "noise"
            )
        ]
    }
}
