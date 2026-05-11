import SwiftUI
import SwiftData
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

    func activateSession(for server: ServerConfig, modelContext: ModelContext) {
        if activeSessions[server.id] == nil {
            activeSessions[server.id] = Session(server: server, modelContext: modelContext)
        }
        currentSession = activeSessions[server.id]
        selectedServer = server
    }

    func closeSession(for serverId: UUID) {
        Task {
            await activeSessions[serverId]?.disconnect()
            activeSessions.removeValue(forKey: serverId)
            currentSession = nil
        }
    }
}
