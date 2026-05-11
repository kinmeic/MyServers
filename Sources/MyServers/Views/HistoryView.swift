import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \CommandRecord.timestamp, order: .reverse) private var allRecords: [CommandRecord]

    private var records: [CommandRecord] {
        guard let serverId = appState.selectedServer?.id else { return [] }
        return allRecords.filter { $0.serverId == serverId }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyHistoryView()
            } else {
                HistoryList(records: records)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem {
                if !records.isEmpty {
                    Button(action: clearHistory) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func clearHistory() {
        for record in records {
            // Access modelContext through environment if needed
        }
    }
}

struct HistoryList: View {
    let records: [CommandRecord]

    var body: some View {
        List(records) { record in
            HistoryRow(record: record)
        }
        .listStyle(.plain)
    }
}

struct HistoryRow: View {
    let record: CommandRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.command)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(2)
                Spacer()
            }

            HStack {
                Text(record.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let duration = record.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let exitCode = record.exitCode {
                    Text("exit \(exitCode)")
                        .font(.caption2)
                        .foregroundStyle(exitCode == 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.command, forType: .string)
            }
            if !record.output.isEmpty {
                Button("Copy output") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.output, forType: .string)
                }
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No commands yet")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
