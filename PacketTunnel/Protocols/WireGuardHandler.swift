import Foundation
import Network

class WireGuardHandler {
    private weak var packetTunnelProvider: NEPacketTunnelProvider?
    private let serverHost: String
    private let serverPort: Int
    private let privateKey: String
    private let publicKey: String
    private var connection: NWConnection?

    init(packetTunnelProvider: NEPacketTunnelProvider, serverHost: String, serverPort: Int, privateKey: String, publicKey: String) {
        self.packetTunnelProvider = packetTunnelProvider
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.privateKey = privateKey
        self.publicKey = publicKey
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let udpOptions = NWProtocolUDP.Options()

        let parameters = NWParameters(udp: udpOptions)

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(serverHost),
            port: NWEndpoint.Port(rawValue: UInt16(serverPort))!
        )

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                completionHandler(nil)
                self?.sendInitialHandshake()
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

    func buildHandshakeInitiation() -> Data {
        var packet = Data()
        let messageType: UInt32 = 1
        var senderIndex: UInt32 = UInt32.random(in: 0...UInt32.max)

        withUnsafeBytes(of: messageType.littleEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: senderIndex.littleEndian) { packet.append(contentsOf: $0) }

        let zeros = Data(repeating: 0, count: 12)
        packet.append(zeros)

        let ephemeralKey = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        packet.append(ephemeralKey)

        let staticKey = Data(base64Encoded: privateKey) ?? Data(repeating: 0, count: 32)
        packet.append(staticKey.prefix(32))

        let timestamp = UInt64(Date().timeIntervalSince1970)
        var tsData = Data()
        withUnsafeBytes(of: timestamp.littleEndian) { tsData.append(contentsOf: $0) }
        packet.append(tsData.prefix(8))

        let mac = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        packet.append(mac)

        return packet
    }

    private func sendInitialHandshake() {
        let handshake = buildHandshakeInitiation()
        connection?.send(content: handshake, completion: .contentProcessed({ error in
            if let error = error {
                print("WG handshake error: \(error)")
            }
        }))
    }

    private func startPacketForwarding() {
        packetTunnelProvider?.packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }
            for packet in packets {
                self.connection?.send(content: packet, completion: .contentProcessed({ error in
                    if let error = error {
                        print("WG send error: \(error)")
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
                print("WG receive error: \(error)")
                return
            }
            if isComplete { return }
            self.receivePackets()
        }
    }
}
