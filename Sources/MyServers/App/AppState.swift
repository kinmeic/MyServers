import SwiftUI
import SwiftData
import Combine

@MainActor
@Observable
final class AppState {
    struct PasswordPromptRequest: Identifiable {
        let id: UUID
        let serverName: String
        let hostSummary: String
    }

    var selectedServer: ServerConfig?
    var activeSessions: [UUID: Session] = [:]
    var currentSession: Session?
    var columnVisibility: NavigationSplitViewVisibility = .all
    var showHistory: Bool = false
    var historyPanelWidth: CGFloat = 320
    var passwordPrompt: PasswordPromptRequest?

    private var transientPasswords: [UUID: String] = [:]

    func session(for server: ServerConfig) -> Session? {
        activeSessions[server.id]
    }

    func activateSession(for server: ServerConfig, modelContext: ModelContext) {
        if activeSessions[server.id] == nil {
            activeSessions[server.id] = Session(server: server, modelContext: modelContext)
        }
        currentSession = activeSessions[server.id]
        selectedServer = server
    }

    func connect(to server: ServerConfig, modelContext: ModelContext) {
        activateSession(for: server, modelContext: modelContext)

        guard let session = activeSessions[server.id] else { return }
        switch session.state {
        case .connected, .connecting:
            return
        case .disconnected, .error:
            let password = transientPasswords[server.id] ?? KeychainManager.getPassword(for: server.id)

            if let password, !password.isEmpty {
                Task {
                    await session.connect(using: password)
                }
            } else {
                passwordPrompt = PasswordPromptRequest(
                    id: server.id,
                    serverName: server.displayName,
                    hostSummary: "\(server.username)@\(server.host):\(server.port)"
                )
            }
        }
    }

    func submitPassword(_ password: String) {
        guard let request = passwordPrompt,
              let session = activeSessions[request.id] else { return }

        transientPasswords[request.id] = password
        passwordPrompt = nil

        Task {
            await session.connect(using: password)
        }
    }

    func cancelPasswordPrompt() {
        passwordPrompt = nil
    }

    func closeSession(for serverId: UUID) {
        Task {
            await activeSessions[serverId]?.disconnect()
            activeSessions.removeValue(forKey: serverId)
            currentSession = nil
        }
    }
}
