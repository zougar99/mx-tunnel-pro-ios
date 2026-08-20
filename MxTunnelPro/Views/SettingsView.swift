import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var vpnManager: VPNManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false
    @State private var deleteOffsets: IndexSet?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Servers")) {
                    ForEach(configManager.servers) { server in
                        NavigationLink(destination: ServerDetailView(server: server)) {
                            HStack {
                                Image(systemName: server.protocolType.icon)
                                    .foregroundStyle(.accent)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(server.name)
                                        .font(.body.bold())
                                    Text("\(server.protocolType.rawValue) - \(server.serverAddress):\(server.serverPort)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        deleteOffsets = offsets
                        showDeleteAlert = true
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Protocol")
                        Spacer()
                        Text("HTTP CONNECT / V2Ray / SSH / SS / WG")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Server?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let offsets = deleteOffsets {
                        configManager.deleteServer(at: offsets)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct ServerDetailView: View {
    let server: ServerConfig

    var body: some View {
        List {
            Section("Protocol") {
                LabeledContent("Type", value: server.protocolType.rawValue)
                LabeledContent("Transport", value: server.transportType.rawValue)
                LabeledContent("Security", value: server.security)
            }

            Section("Server") {
                LabeledContent("Address", value: server.serverAddress)
                LabeledContent("Port", value: "\(server.serverPort)")
            }

            if !server.uuid.isEmpty {
                Section("VMess/VLess") {
                    LabeledContent("UUID", value: server.uuid)
                    LabeledContent("Alter ID", value: "\(server.alterId)")
                }
            }

            if !server.sni.isEmpty {
                Section("TLS") {
                    LabeledContent("SNI", value: server.sni)
                    if !server.host.isEmpty {
                        LabeledContent("Host", value: server.host)
                    }
                    if !server.path.isEmpty {
                        LabeledContent("Path", value: server.path)
                    }
                }
            }
        }
        .navigationTitle(server.name)
    }
}
