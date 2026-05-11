import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@MainActor
@Observable
final class Session {
    let id: UUID
    let server: ServerConfig
    var state: ConnectionState = .disconnected
    var lastActivity: Date?
    var terminalView: TerminalBridge?
    var history: [CommandRecord] = []

    private var sshSession: SSHSession?

    init(server: ServerConfig) {
        self.id = server.id
        self.server = server
    }

    func connect() async {
        state = .connecting
        do {
            let password = KeychainManager.getPassword(for: server.id) ?? ""
            print("[Session] Connecting to \(server.host):\(server.port) as \(server.username)")
            let info = SSHConnectionInfo(
                host: server.host,
                port: server.port,
                username: server.username,
                password: password
            )
            let session = SSHSession(info: info)
            self.sshSession = session

            await session.setDisconnectHandler { [weak self] in
                Task { @MainActor in
                    self?.state = .disconnected
                }
            }

            try await session.connect()

            self.terminalView = TerminalBridge(session: session)
            state = .connected
            lastActivity = Date()
            server.lastConnectedAt = Date()
            print("[Session] Connected to \(server.host)")
        } catch {
            print("[Session] Connection failed: \(error)")
            let message = connectionErrorMessage(for: error)
            state = .error(message)
        }
    }

    private func connectionErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "NIOCore.ChannelError" {
            switch nsError.code {
            case 0: return "Connection timed out. Please check the host and port are correct."
            default: return "Network error: \(error.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    func disconnect() async {
        await sshSession?.disconnect()
        sshSession = nil
        terminalView = nil
        state = .disconnected
    }

    func recordCommand(_ command: String, output: String = "") {
        let record = CommandRecord(
            serverId: server.id,
            command: command,
            output: output
        )
        history.append(record)
    }
}
