import SwiftUI

struct TerminalContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let server = appState.selectedServer,
               let session = appState.session(for: server) {
                TerminalContentView(session: session)
            } else if let server = appState.selectedServer {
                EmptyTerminalView(
                    icon: "server.rack",
                    title: server.displayName,
                    message: "已选择服务器，准备开始连接。",
                    buttonTitle: "立即连接"
                ) {
                    appState.activateSession(for: server, modelContext: modelContext)
                }
            } else {
                EmptyTerminalView(
                    icon: "terminal",
                    title: "选择一台服务器开始",
                    message: "从左侧挑选一个已保存的服务器，或者先新增一个连接配置。"
                )
            }
        }
    }
}

struct TerminalContentView: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
            TerminalToolbar(session: session)

            if let bridge = session.terminalView {
                TerminalViewRepresentable(bridge: bridge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ConnectionPlaceholder(state: session.state) {
                    Task { await session.connect() }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task {
            if case .disconnected = session.state {
                await session.connect()
            }
        }
    }
}

struct TerminalToolbar: View {
    let session: Session

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.server.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text("\(session.server.username)@\(session.server.host):\(session.server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusTint)

            Button(action: { Task { await session.disconnect() } }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("关闭连接")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusColor: Color {
        switch session.state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .secondary
        case .error: .red
        }
    }

    private var statusTint: Color {
        switch session.state {
        case .connected: .secondary
        case .connecting: .orange
        case .disconnected: .secondary
        case .error: .red
        }
    }

    private var statusText: String {
        switch session.state {
        case .connected:
            if let last = session.lastActivity {
                return "最近活动：\(relativeDateFormatter.localizedString(for: last, relativeTo: .now))"
            }
            return "已连接"
        case .connecting:
            return "连接中..."
        case .disconnected:
            return "未连接"
        case .error(let message):
            return message
        }
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
}

struct EmptyTerminalView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct ConnectionPlaceholder: View {
    let state: ConnectionState
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .disconnected:
                Button("连接", action: onConnect)
                    .buttonStyle(.borderedProminent)
            case .connecting:
                ProgressView()
                    .scaleEffect(1.5)
                Text("正在建立连接...")
                    .foregroundStyle(.secondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试", action: onConnect)
            case .connected:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
