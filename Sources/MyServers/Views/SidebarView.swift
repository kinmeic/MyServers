import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerConfig.createdAt, order: .reverse) private var servers: [ServerConfig]
    @Query(sort: \CommandRecord.timestamp, order: .reverse) private var allRecords: [CommandRecord]
    @State private var showAddSheet = false
    @State private var editingServer: ServerConfig?
    @State private var showImporter = false
    @State private var exportDocument: ServerListDocument?
    @State private var exportDefaultURL = URL.documentsDirectory.appending(path: "myservers-servers.json")
    @State private var importExportMessage: String?
    @State private var importExportIsError = false

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            if let importExportMessage {
                Label(importExportMessage, systemImage: importExportIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(importExportIsError ? .orange : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((importExportIsError ? Color.orange : Color.green).opacity(0.08))
            }

            List(selection: $state.selectedServer) {
                Section("在线连接") {
                    if activeServers.isEmpty {
                        Text("无")
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(activeServers) { server in
                            ServerRow(server: server, isActive: true, pingResult: appState.pingService.results[server.id])
                                .tag(server)
                                .contextMenu {
                                    Button("断开连接") {
                                        appState.closeSession(for: server.id)
                                    }
                                }
                        }
                    }
                }

                if !inactiveServers.isEmpty {
                    Section("已保存") {
                        ForEach(inactiveServers) { server in
                            ServerRow(server: server, isActive: false, pingResult: appState.pingService.results[server.id])
                                .tag(server)
                                .contextMenu {
                                    Button("连接") {
                                        appState.connect(to: server, modelContext: modelContext)
                                    }
                                    Button("检测延迟") {
                                        appState.pingServer(server)
                                    }
                                    Button("编辑") {
                                        editingServer = server
                                    }
                                    Divider()
                                    Button("删除", role: .destructive) {
                                        modelContext.delete(server)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("服务器")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("新增服务器") {
                            showAddSheet = true
                        }

                        Divider()

                        Button("导入 JSON") {
                            showImporter = true
                        }

                        Button("导出 JSON") {
                            prepareExport()
                        }
                        .disabled(servers.isEmpty)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .help("新增、导入或导出服务器")
                }
            }
            .overlay {
                if servers.isEmpty {
                    ContentUnavailableView(
                        "还没有服务器",
                        systemImage: "server.rack",
                        description: Text("先添加一个服务器，之后就可以直接在这里发起 SSH 连接。")
                    )
                }
            }

            // Reorder buttons
            HStack {
                Spacer()
                Button(action: moveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(canMoveUp ? .secondary : .quaternary)
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveUp)

                Button(action: moveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(canMoveDown ? .secondary : .quaternary)
                }
                .buttonStyle(.borderless)
                .disabled(!canMoveDown)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .sheet(isPresented: $showAddSheet) {
            ServerFormView()
        }
        .sheet(item: $editingServer) { server in
            ServerFormView(server: server)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.myServersJSON, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { isPresented in
                    if !isPresented {
                        exportDocument = nil
                    }
                }
            ),
            document: exportDocument,
            contentType: .myServersJSON,
            defaultFilename: exportDefaultURL.deletingPathExtension().lastPathComponent
        ) { result in
            handleExport(result)
        }
    }

    private var activeServers: [ServerConfig] {
        servers.filter { server in
            if let session = appState.activeSessions[server.id] {
                return session.state == .connected
            }
            return false
        }
    }

    private var inactiveServers: [ServerConfig] {
        servers.filter { server in
            if let session = appState.activeSessions[server.id] {
                return session.state != .connected
            }
            return true
        }
        .sorted { a, b in
            (a.sortOrder ?? Int.max) < (b.sortOrder ?? Int.max)
        }
    }

    // MARK: - Reorder

    private func indexOfSelected(in list: [ServerConfig]) -> Int? {
        guard let selected = appState.selectedServer else { return nil }
        return list.firstIndex(where: { $0.id == selected.id })
    }

    private var canMoveUp: Bool {
        guard let index = indexOfSelected(in: inactiveServers), index > 0 else { return false }
        return true
    }

    private var canMoveDown: Bool {
        let list = inactiveServers
        guard let index = indexOfSelected(in: list), index < list.count - 1 else { return false }
        return true
    }

    private func moveUp() {
        var list = inactiveServers
        guard let index = indexOfSelected(in: list), index > 0 else { return }
        list.swapAt(index, index - 1)
        for (i, server) in list.enumerated() {
            server.sortOrder = i
        }
    }

    private func moveDown() {
        var list = inactiveServers
        guard let index = indexOfSelected(in: list), index < list.count - 1 else { return }
        list.swapAt(index, index + 1)
        for (i, server) in list.enumerated() {
            server.sortOrder = i
        }
    }

    // MARK: - Import/Export

    private func prepareExport() {
        let items = servers.map { server in
            let commands = allRecords
                .filter { $0.serverId == server.id && $0.isPinned }
                .sorted { $0.timestamp > $1.timestamp }
                .map(CommonCommandItem.init(record:))
            return ServerListItem(server: server, commonCommands: commands)
        }
        exportDocument = ServerListDocument(payload: ServerListPayload(servers: items))
        exportDefaultURL = URL.documentsDirectory.appending(path: "myservers-servers-\(Date.now.formatted(.iso8601.year().month().day())).json")
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            showStatus("已导出到 \(url.lastPathComponent)")
        case .failure(let error):
            showStatus("导出失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder.serverListDecoder.decode(ServerListPayload.self, from: data)
                let importedCount = try importServers(from: payload)
                showStatus("已导入 \(importedCount) 台服务器")
            } catch {
                showStatus("导入失败：\(error.localizedDescription)", isError: true)
            }
        case .failure(let error):
            showStatus("导入失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func importServers(from payload: ServerListPayload) throws -> Int {
        var imported = 0

        for item in payload.servers {
            let targetServer: ServerConfig
            if let existing = servers.first(where: {
                $0.host == item.host &&
                $0.port == item.port &&
                $0.username == item.username
            }) {
                item.apply(to: existing)
                targetServer = existing
            } else {
                let created = item.makeServerConfig()
                modelContext.insert(created)
                targetServer = created
            }

            replaceCommonCommands(for: targetServer, with: item.commonCommands)
            imported += 1
        }

        try modelContext.save()
        return imported
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        importExportMessage = message
        importExportIsError = isError
        Task {
            try? await Task.sleep(for: .seconds(3))
            self.importExportMessage = nil
        }
    }

    private func replaceCommonCommands(for server: ServerConfig, with commands: [CommonCommandItem]) {
        let existingPinned = allRecords.filter { $0.serverId == server.id && $0.isPinned }
        for record in existingPinned {
            modelContext.delete(record)
        }

        for command in commands where !command.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let record = CommandRecord(
                serverId: server.id,
                command: command.command,
                isPinned: true
            )
            modelContext.insert(record)
        }
    }
}

struct ServerRow: View {
    let server: ServerConfig
    let isActive: Bool
    var pingResult: PingResult?

    var body: some View {
        HStack {
            Image(systemName: isActive ? "bolt.horizontal.circle.fill" : "server.rack")
                .foregroundStyle(isActive ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text("\(server.username)@\(server.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            }

            Spacer()

            if let pingResult {
                switch pingResult {
                case .latency(let ms):
                    Text(String(format: "%.0fms", ms))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ms < 100 ? .green : ms < 300 ? .orange : .red)
                case .timeout:
                    Text("超时")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            } else if isActive {
                Text("在线")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
