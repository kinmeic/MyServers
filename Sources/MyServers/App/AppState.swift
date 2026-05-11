import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    var selectedServer: ServerConfig?
    var activeSessions: [UUID: Session] = [:]
    var currentSession: Session?
    var columnVisibility: NavigationSplitViewVisibility = .all
    var showHistory: Bool = true

    func session(for server: ServerConfig) -> Session? {
        activeSessions[server.id]
    }

    func activateSession(for server: ServerConfig) {
        if activeSessions[server.id] == nil {
            activeSessions[server.id] = Session(server: server)
        }
        currentSession = activeSessions[server.id]
        selectedServer = server
    }

    func closeSession(for serverId: UUID) {
        Task {
            await activeSessions[serverId]?.disconnect()
            activeSessions.removeValue(forKey: serverId)
            if selectedServer?.id == serverId {
                selectedServer = nil
                currentSession = nil
            }
        }
    }
}
