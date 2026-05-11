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

    let pingService = PingService()

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
            // Prefer in-memory password, then try Keychain
            let password = transientPasswords[server.id] ?? KeychainManager.getPassword(for: server.id)

            if let password, !password.isEmpty {
                Task {
                    await session.connect(using: password)
                    if session.state == .connected {
                        refreshPingTimer()
                    }
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
        KeychainManager.savePassword(password, for: request.id)
        passwordPrompt = nil

        Task {
            await session.connect(using: password)
        }
    }

    func cancelPasswordPrompt() {
        guard let request = passwordPrompt else { return }
        passwordPrompt = nil
        activeSessions.removeValue(forKey: request.id)
        if currentSession?.server.id == request.id {
            currentSession = nil
        }
    }

    func closeSession(for serverId: UUID) {
        Task {
            await activeSessions[serverId]?.disconnect()
            activeSessions.removeValue(forKey: serverId)
            pingService.results.removeValue(forKey: serverId)
            if currentSession?.server.id == serverId {
                currentSession = activeSessions.values.first
                selectedServer = currentSession?.server
            }
            refreshPingTimer()
        }
    }

    func pingServer(_ server: ServerConfig) {
        Task {
            let result = await pingService.ping(host: server.host, port: server.port)
            pingService.results[server.id] = result
        }
    }

    func refreshPingTimer() {
        let connected = activeSessions.values.filter { $0.state == .connected }
        if connected.isEmpty {
            pingService.stopTimer()
        } else {
            let targets = connected.map { ($0.server.id, $0.server.host, $0.server.port) }
            pingService.startTimer { targets }
        }
    }
}
