import Foundation

enum TunnelProtocol: String, CaseIterable, Codable, Identifiable {
    case http = "HTTP Tunnel"
    case ssh = "SSH Tunnel"
    case vmess = "VMess"
    case vless = "VLess"
    case shadowsocks = "Shadowsocks"
    case wireGuard = "WireGuard"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .http: return "globe"
        case .ssh: return "key"
        case .vmess: return "bolt.fill"
        case .vless: return "bolt.circle"
        case .shadowsocks: return "shield.checkered"
        case .wireGuard: return "lock.shield"
        }
    }
}

enum TransportType: String, CaseIterable, Codable, Identifiable {
    case tcp = "TCP"
    case ws = "WebSocket"
    case grpc = "gRPC"
    case http = "HTTP/2"

    var id: String { rawValue }
}

struct ServerConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var protocolType: TunnelProtocol
    var serverAddress: String
    var serverPort: UInt16
    var transportType: TransportType
    var security: String
    var sni: String
    var host: String
    var path: String
    var username: String
    var password: String
    var uuid: String
    var alterId: Int
    var network: String
    var allowInsecure: Bool

    init(
        name: String = "",
        protocolType: TunnelProtocol = .http,
        serverAddress: String = "",
        serverPort: UInt16 = 443,
        transportType: TransportType = .tcp,
        security: String = "tls",
        sni: String = "",
        host: String = "",
        path: String = "",
        username: String = "",
        password: String = "",
        uuid: String = "",
        alterId: Int = 0,
        network: String = "tcp",
        allowInsecure: Bool = false
    ) {
        self.name = name
        self.protocolType = protocolType
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.transportType = transportType
        self.security = security
        self.sni = sni
        self.host = host
        self.path = path
        self.username = username
        self.password = password
        self.uuid = uuid
        self.alterId = alterId
        self.network = network
        self.allowInsecure = allowInsecure
    }

    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "protocolType": protocolType.rawValue,
            "serverAddress": serverAddress,
            "serverPort": serverPort,
            "transportType": transportType.rawValue,
            "security": security,
            "sni": sni,
            "host": host,
            "path": path,
            "username": username,
            "password": password,
            "uuid": uuid,
            "alterId": alterId,
            "network": network,
            "allowInsecure": allowInsecure
        ]
    }
}

struct ConfigPayload: Codable {
    var servers: [ServerConfig]
    var lastUsedId: UUID?
}
