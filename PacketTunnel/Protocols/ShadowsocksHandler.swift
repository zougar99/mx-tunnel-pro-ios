import Foundation
import CryptoKit
import NetworkExtension
import Network

class ShadowsocksHandler {
    private weak var packetTunnelProvider: NEPacketTunnelProvider?
    private let serverHost: String
    private let serverPort: Int
    private let password: String
    private let encryptionMethod: String
    private var connection: NWConnection?

    init(packetTunnelProvider: NEPacketTunnelProvider, serverHost: String, serverPort: Int, password: String, encryptionMethod: String) {
        self.packetTunnelProvider = packetTunnelProvider
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.password = password
        self.encryptionMethod = encryptionMethod
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

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

    func deriveKey() -> SymmetricKey {
        let salt = Data("mx-tunnel-pro-salt".utf8)
        let passwordData = Data(password.utf8)

        let keyLength: Int
        switch encryptionMethod {
        case "aes-128-gcm": keyLength = 16
        case "aes-192-gcm": keyLength = 24
        default: keyLength = 32
        }

        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("ss-subkey".utf8),
            outputByteCount: keyLength
        )

        return derived
    }

    func encrypt(data: Data) -> Data? {
        let key = deriveKey()
        var nonceBytes = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
        guard let nonce = try? AES.GCM.Nonce(data: nonceBytes) else { return nil }
        guard let sealedBox = try? AES.GCM.seal(data, using: key, nonce: nonce) else { return nil }
        var result = nonceBytes
        result.append(contentsOf: sealedBox.ciphertext)
        result.append(contentsOf: sealedBox.tag)
        return result
    }

    func decrypt(data: Data) -> Data? {
        guard data.count > 28 else { return nil }
        let key = deriveKey()
        let nonceData = data.prefix(12)
        let ciphertext = data[data.startIndex + 12 ..< data.endIndex - 16]
        let tag = data.suffix(16)

        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else { return nil }
        guard let sealedBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag) else { return nil }
        return try? AES.GCM.open(sealedBox, using: key)
    }

    private func startPacketForwarding() {
        packetTunnelProvider?.packetFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            for packet in packets {
                if let encrypted = self.encrypt(data: packet) {
                    self.connection?.send(content: encrypted, completion: .contentProcessed({ error in
                        if let error = error {
                            print("SS send error: \(error)")
                        }
                    }))
                }
            }
            self.receivePackets()
        }
    }

    private func receivePackets() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                if let decrypted = self.decrypt(data: data) {
                    self.packetTunnelProvider?.packetFlow.writePackets([decrypted], withProtocols: [NSNumber(value: AF_INET)])
                }
            }
            if let error = error {
                print("SS receive error: \(error)")
                return
            }
            if isComplete { return }
            self.receivePackets()
        }
    }
}
