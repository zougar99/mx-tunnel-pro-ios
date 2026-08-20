import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var configManager: ConfigManager
    @State private var showAddServer = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                ConnectionStatusView()

                Spacer()

                ProtocolInfoView()

                Spacer()

                ConnectButton()

                Spacer(minLength: 20)

                ServerPickerView()

                Spacer(minLength: 10)
            }
            .navigationTitle("MX Tunnel Pro")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddServer = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddServer) {
                AddServerView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject var vpnManager: VPNManager

    var statusColor: Color {
        switch vpnManager.status {
        case .connected: return .green
        case .connecting, .disconnecting: return .yellow
        case .disconnected, .invalid: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: vpnManager.status == .connected ? "lock.shield.fill" : "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: vpnManager.status == .connecting)

            Text(vpnManager.status.rawValue)
                .font(.title2.bold())
                .foregroundStyle(statusColor)

            if vpnManager.status == .connected {
                Text(vpnManager.connectionDuration)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 30)
    }
}

struct ProtocolInfoView: View {
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        if let server = configManager.selectedServer {
            HStack(spacing: 20) {
                Label(server.protocolType.rawValue, systemImage: server.protocolType.icon)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)

                Label(server.serverAddress, systemImage: "globe")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)

                Label("\(server.serverPort)", systemImage: "number")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
    }
}

struct ConnectButton: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var configManager: ConfigManager

    var isConnecting: Bool {
        vpnManager.status == .connecting || vpnManager.status == .disconnecting
    }

    var body: some View {
        Button(action: {
            guard let server = configManager.selectedServer else { return }
            vpnManager.toggle(config: server)
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: vpnManager.status == .connected
                                ? [.red, .orange]
                                : [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: vpnManager.status == .connected ? .red.opacity(0.5) : .blue.opacity(0.5), radius: 20)

                if isConnecting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: vpnManager.status == .connected ? "stop.fill" : "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isConnecting)
    }
}

struct ServerPickerView: View {
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Servers")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(configManager.servers) { server in
                        ServerCard(server: server, isSelected: server.id == configManager.selectedServerId)
                            .onTapGesture {
                                configManager.selectServer(server)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ServerCard: View {
    let server: ServerConfig
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: server.protocolType.icon)
                    .font(.caption)
                Text(server.name)
                    .font(.caption.bold())
                    .lineLimit(1)
            }

            Text(server.serverAddress.isEmpty ? "Not configured" : server.serverAddress)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(minWidth: 120)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(VPNManager())
        .environmentObject(ConfigManager())
}
