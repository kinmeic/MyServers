import Foundation
import SwiftData

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

    private var sshSession: SSHSession?
    private let modelContext: ModelContext

    init(server: ServerConfig, modelContext: ModelContext) {
        self.id = server.id
        self.server = server
        self.modelContext = modelContext
    }

    func connect(using password: String) async {
        state = .connecting
        do {
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

            let bridge = TerminalBridge(session: session)
            self.terminalView = bridge
            state = .connected
            lastActivity = Date()
            server.lastConnectedAt = Date()
            print("[Session] Connected to \(server.host)")
        } catch {
            print("[Session] Connection failed: \(error)")
            let message = connectionErrorMessage(for: error)
            state = .error(message)
            terminalView = nil
            sshSession = nil
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
}
