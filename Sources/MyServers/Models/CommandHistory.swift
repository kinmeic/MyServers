import Foundation
import SwiftData

@Model
final class CommandRecord {
    @Attribute(.unique) var id: UUID
    var serverId: UUID
    var command: String
    var output: String
    var timestamp: Date
    var exitCode: Int?
    var duration: TimeInterval?
    var isPinned: Bool = false

    init(
        id: UUID = UUID(),
        serverId: UUID,
        command: String,
        output: String = "",
        timestamp: Date = Date(),
        exitCode: Int? = nil,
        duration: TimeInterval? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.serverId = serverId
        self.command = command
        self.output = output
        self.timestamp = timestamp
        self.exitCode = exitCode
        self.duration = duration
        self.isPinned = isPinned
    }
}
