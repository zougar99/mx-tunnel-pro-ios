import Foundation

enum TunnelProtocol: String, CaseIterable {
    case http = "HTTP Tunnel"
    case ssh = "SSH Tunnel"
    case vmess = "VMess"
    case vless = "VLess"
    case shadowsocks = "Shadowsocks"
    case wireGuard = "WireGuard"
}
