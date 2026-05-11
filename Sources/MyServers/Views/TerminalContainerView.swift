import SwiftUI

struct TerminalContainerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let server = appState.selectedServer,
               let session = appState.session(for: server) {
                TerminalContentView(session: session)
            } else {
                EmptyTerminalView()
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
                    .padding(8)
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
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(session.server.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text("(\(session.server.host):\(session.server.port))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .connected = session.state, let last = session.lastActivity {
                Text("Last activity: \(last, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: { Task { await session.disconnect() } }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Close session")
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
}

struct EmptyTerminalView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select or create a server")
                .font(.title3)
                .foregroundStyle(.secondary)
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
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
            case .connecting:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Connecting...")
                    .foregroundStyle(.secondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: onConnect)
            case .connected:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
