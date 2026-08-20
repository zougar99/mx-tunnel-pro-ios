import SwiftUI

struct AddServerView: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var protocolType: TunnelProtocol = .http
    @State private var serverAddress = ""
    @State private var serverPort = "443"
    @State private var transportType: TransportType = .tcp
    @State private var security = "tls"
    @State private var sni = ""
    @State private var host = ""
    @State private var path = ""
    @State private var username = ""
    @State private var password = ""
    @State private var uuid = ""
    @State private var alterId = "0"
    @State private var allowInsecure = false
    @State private var importMode = false
    @State private var importText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Import Config", isOn: $importMode)
                }

                if importMode {
                    Section(header: Text("Paste Config")) {
                        TextEditor(text: $importText)
                            .frame(minHeight: 200)
                            .font(.system(.body, design: .monospaced))

                        Button("Import") {
                            if configManager.importConfig(from: importText) {
                                dismiss()
                            }
                        }
                        .disabled(importText.isEmpty)
                    }
                } else {
                    Section(header: Text("General")) {
                        TextField("Server Name", text: $name)
                        Picker("Protocol", selection: $protocolType) {
                            ForEach(TunnelProtocol.allCases) { proto in
                                Label(proto.rawValue, systemImage: proto.icon).tag(proto)
                            }
                        }
                    }

                    Section(header: Text("Server")) {
                        TextField("Server Address", text: $serverAddress)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        TextField("Port", text: $serverPort)
                            .keyboardType(.numberPad)
                    }

                    Section(header: Text("Connection")) {
                        Picker("Transport", selection: $transportType) {
                            ForEach(TransportType.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }

                        Picker("Security", selection: $security) {
                            Text("TLS").tag("tls")
                            Text("None").tag("none")
                            Text("AES-256-GCM").tag("aes-256-gcm")
                            Text("Chacha20-Poly1305").tag("chacha20-ietf-poly1305")
                            Text("Noise").tag("noise")
                        }
                    }

                    if protocolType == .vmess || protocolType == .vless {
                        Section(header: Text("VMess/VLess")) {
                            TextField("UUID", text: $uuid)
                                .autocapitalization(.none)
                            TextField("Alter ID", text: $alterId)
                                .keyboardType(.numberPad)
                        }
                    }

                    if protocolType == .http || protocolType == .ssh {
                        Section(header: Text("Authentication")) {
                            TextField("Username", text: $username)
                                .autocapitalization(.none)
                            SecureField("Password", text: $password)
                        }
                    }

                    Section(header: Text("TLS Settings")) {
                        TextField("SNI", text: $sni)
                            .autocapitalization(.none)
                        TextField("Host", text: $host)
                            .autocapitalization(.none)
                        TextField("Path", text: $path)
                            .autocapitalization(.none)
                        Toggle("Allow Insecure", isOn: $allowInsecure)
                    }
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let config = ServerConfig(
                            name: name.isEmpty ? "\(protocolType.rawValue) Server" : name,
                            protocolType: protocolType,
                            serverAddress: serverAddress,
                            serverPort: UInt16(serverPort) ?? 443,
                            transportType: transportType,
                            security: security,
                            sni: sni,
                            host: host,
                            path: path,
                            username: username,
                            password: password,
                            uuid: uuid,
                            alterId: Int(alterId) ?? 0,
                            allowInsecure: allowInsecure
                        )
                        configManager.addServer(config)
                        dismiss()
                    }
                    .disabled(serverAddress.isEmpty)
                }
            }
        }
    }
}
