import NetworkExtension
import Network
import Foundation

class HTTPConnectHandler {
    private weak var packetTunnelProvider: NEPacketTunnelProvider?
    private let serverHost: String
    private let serverPort: Int
    private let username: String
    private let password: String
    private var connection: NWConnection?

    init(packetTunnelProvider: NEPacketTunnelProvider, serverHost: String, serverPort: Int, username: String, password: String) {
        self.packetTunnelProvider = packetTunnelProvider
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.username = username
        self.password = password
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(serverHost),
            port: NWEndpoint.Port(rawValue: UInt16(serverPort))!
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

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

    private func startPacketForwarding() {
        packetTunnelProvider?.packetFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            for packet in packets {
                self.connection?.send(content: packet, completion: .contentProcessed({ error in
                    if let error = error {
                        print("HTTP send error: \(error)")
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
                print("HTTP receive error: \(error)")
                return
            }
            if isComplete {
                return
            }
            self.receivePackets()
        }
    }
}
