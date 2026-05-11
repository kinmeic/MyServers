import Foundation
import SwiftData

enum AuthType: String, Codable {
    case password
    case privateKey
    case secureEnclave
}

@Model
final class ServerConfig {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authTypeRaw: String
    var keyIdentifier: String?
    var createdAt: Date
    var lastConnectedAt: Date?
    var tags: [String]

    var authType: AuthType {
        get { AuthType(rawValue: authTypeRaw) ?? .password }
        set { authTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: AuthType = .password,
        keyIdentifier: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name.isEmpty ? host : name
        self.host = host
        self.port = port
        self.username = username
        self.authTypeRaw = authType.rawValue
        self.keyIdentifier = keyIdentifier
        self.createdAt = Date()
        self.tags = tags
    }

    var displayName: String { name.isEmpty ? host : name }
}
