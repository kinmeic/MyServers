import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \CommandRecord.timestamp, order: .reverse) private var allRecords: [CommandRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var editingRecord: CommandRecord?

    private var commonCommands: [CommandRecord] {
        guard let serverId = appState.selectedServer?.id else { return [] }
        return allRecords
            .filter { $0.serverId == serverId && $0.isPinned }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            HistoryHeader {
                showAddSheet = true
            }

            Group {
            if appState.selectedServer == nil {
                EmptyHistoryView(
                    title: "还没有选中服务器",
                    message: "选择左侧服务器后，这里会显示对应的常用命令。"
                )
            } else if commonCommands.isEmpty {
                EmptyHistoryView(
                    title: "还没有常用命令",
                    message: "点右上角“添加命令”，把常用 SSH 命令保存到这里。"
                )
            } else {
                CommonCommandList(
                    records: commonCommands,
                    onInsert: insertCommand,
                    onEdit: { editingRecord = $0 }
                )
            }
        }
        }
        .navigationTitle("常用命令")
        .sheet(isPresented: $showAddSheet) {
            CommandEditorSheet { command in
                addCommand(command)
            }
        }
        .sheet(item: $editingRecord) { record in
            CommandEditorSheet(initialCommand: record.command) { command in
                record.command = command
                record.timestamp = .now
                try? modelContext.save()
            }
        }
    }
}

private struct HistoryHeader: View {
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("常用命令")
                    .font(.headline)
                Text("双击可自动输入到当前终端")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("添加命令", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct CommonCommandList: View {
    let records: [CommandRecord]
    let onInsert: (CommandRecord) -> Void
    let onEdit: (CommandRecord) -> Void

    var body: some View {
        List {
            Section("常用命令") {
                ForEach(records) { record in
                    CommonCommandRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onInsert(record)
                        }
                        .contextMenu {
                            Button("插入到终端") {
                                onInsert(record)
                            }
                            Button("编辑") {
                                onEdit(record)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct CommonCommandRow: View {
    let record: CommandRecord

    var body: some View {
        Text(record.command)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private struct CommandEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var command: String
    let onSave: (String) -> Void

    init(initialCommand: String = "", onSave: @escaping (String) -> Void) {
        _command = State(initialValue: initialCommand)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("常用命令")
                .font(.title3.weight(.semibold))

            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                }

            Text("支持多行命令。保存后，双击即可直接输入到当前终端。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("保存") {
                    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private extension HistoryView {
    func addCommand(_ command: String) {
        guard let serverId = appState.selectedServer?.id else { return }

        let record = CommandRecord(
            serverId: serverId,
            command: command,
            isPinned: true
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    func insertCommand(_ record: CommandRecord) {
        guard let server = appState.selectedServer,
              let bridge = appState.session(for: server)?.terminalView else { return }
        bridge.insertCommand(record.command)
    }
}

private struct EmptyHistoryView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
