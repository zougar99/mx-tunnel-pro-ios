import Foundation
import NetworkExtension
import Network

class V2RayHandler {
    private weak var packetTunnelProvider: NEPacketTunnelProvider?
    private let serverHost: String
    private let serverPort: Int
    private let uuid: String
    private let security: String
    private let sni: String
    private let transport: String
    private var connection: NWConnection?

    init(packetTunnelProvider: NEPacketTunnelProvider, serverHost: String, serverPort: Int, uuid: String, security: String, sni: String, transport: String) {
        self.packetTunnelProvider = packetTunnelProvider
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.uuid = uuid
        self.security = security
        self.sni = sni
        self.transport = transport
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true

        let parameters: NWParameters
        if security == "tls" {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(serverHost),
            port: NWEndpoint.Port(rawValue: UInt16(serverPort))!
        )

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                completionHandler(nil)
                self?.startPacketForwarding()
            case .failed(let error):
                completionHandler(error)
            case .waiting(let error):
                completionHandler(error)
            default:
                break
            }
        }

        connection?.start(queue: .global())
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    func buildVMessHeader(targetHost: String, targetPort: Int) -> Data {
        let timestamp = Int(Date().timeIntervalSince1970)
        var header = Data()

        let uuidClean = uuid.replacingOccurrences(of: "-", with: "")
        if let uuidData = Data(hexString: uuidClean) {
            header.append(uuidData)
        }

        header.append(UInt8(timestamp & 0xFF))
        header.append(UInt8((timestamp >> 8) & 0xFF))
        header.append(UInt8((timestamp >> 16) & 0xFF))
        header.append(UInt8((timestamp >> 24) & 0xFF))
        header.append(UInt8((timestamp >> 32) & 0xFF))
        header.append(UInt8((timestamp >> 40) & 0xFF))
        header.append(UInt8((timestamp >> 48) & 0xFF))
        header.append(UInt8((timestamp >> 56) & 0xFF))

        header.append(0x01)

        if let hostData = targetHost.data(using: .utf8) {
            header.append(UInt8(hostData.count))
            header.append(hostData)
        } else {
            header.append(0)
        }

        header.append(UInt8((targetPort >> 8) & 0xFF))
        header.append(UInt8(targetPort & 0xFF))

        return header
    }

    private func startPacketForwarding() {
        packetTunnelProvider?.packetFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            for packet in packets {
                self.connection?.send(content: packet, completion: .contentProcessed({ error in
                    if let error = error {
                        print("V2Ray send error: \(error)")
                    }
                }))
            }
            self.receivePackets()
        }
    }

    private func receivePackets() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.packetTunnelProvider?.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
            }
            if let error = error {
                print("V2Ray receive error: \(error)")
                return
            }
            if isComplete { return }
            self.receivePackets()
        }
    }
}

extension Data {
    init?(hexString: String) {
        let hex = hexString.dropFirst(hexString.count % 2)
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
