import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerConfig.createdAt, order: .reverse) private var servers: [ServerConfig]
    @State private var showAddSheet = false
    @State private var editingServer: ServerConfig?

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedServer) {
            Section("Active") {
                ForEach(activeServers) { server in
                    ServerRow(server: server, isActive: true)
                        .tag(server)
                        .contextMenu {
                            Button("Disconnect") {
                                appState.closeSession(for: server.id)
                            }
                        }
                }
            }

            Section("Saved") {
                ForEach(inactiveServers) { server in
                    ServerRow(server: server, isActive: false)
                        .tag(server)
                        .contextMenu {
                            Button("Connect") {
                                appState.activateSession(for: server, modelContext: modelContext)
                            }
                            Button("Edit") {
                                editingServer = server
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                modelContext.delete(server)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem {
                Button(action: { appState.showHistory.toggle() }) {
                    Image(systemName: "sidebar.right")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ServerFormView()
        }
        .sheet(item: $editingServer) { server in
            ServerFormView(server: server)
        }
    }

    private var activeServers: [ServerConfig] {
        servers.filter { appState.activeSessions[$0.id] != nil }
    }

    private var inactiveServers: [ServerConfig] {
        servers.filter { appState.activeSessions[$0.id] == nil }
    }

}

struct ServerRow: View {
    let server: ServerConfig
    let isActive: Bool

    var body: some View {
        HStack {
            Image(systemName: isActive ? "desktopcomputer" : "desktopcomputer")
                .foregroundStyle(isActive ? .green : .secondary)
                .symbolVariant(isActive ? .fill : .none)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text("\(server.username)@\(server.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
    }
}
