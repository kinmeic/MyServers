import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let myServersJSON = UTType(exportedAs: "com.myservers.server-list+json", conformingTo: .json)
}

struct ServerListDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.myServersJSON, .json] }

    var payload: ServerListPayload

    init(payload: ServerListPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        payload = try JSONDecoder.serverListDecoder.decode(ServerListPayload.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.serverListEncoder.encode(payload)
        return .init(regularFileWithContents: data)
    }
}

struct ServerListPayload: Codable {
    var version: Int
    var exportedAt: Date
    var servers: [ServerListItem]

    init(version: Int = 1, exportedAt: Date = Date(), servers: [ServerListItem]) {
        self.version = version
        self.exportedAt = exportedAt
        self.servers = servers
    }
}

struct ServerListItem: Codable {
    var name: String
    var host: String
    var port: Int
    var username: String
    var authType: AuthType
    var keyIdentifier: String?
    var tags: [String]
    var lastConnectedAt: Date?
    var commonCommands: [CommonCommandItem]

    enum CodingKeys: String, CodingKey {
        case name
        case host
        case port
        case username
        case authType
        case keyIdentifier
        case tags
        case lastConnectedAt
        case commonCommands
    }

    init(server: ServerConfig, commonCommands: [CommonCommandItem]) {
        self.name = server.name
        self.host = server.host
        self.port = server.port
        self.username = server.username
        self.authType = server.authType
        self.keyIdentifier = server.keyIdentifier
        self.tags = server.tags
        self.lastConnectedAt = server.lastConnectedAt
        self.commonCommands = commonCommands
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.host = try container.decode(String.self, forKey: .host)
        self.port = try container.decode(Int.self, forKey: .port)
        self.username = try container.decode(String.self, forKey: .username)
        self.authType = try container.decode(AuthType.self, forKey: .authType)
        self.keyIdentifier = try container.decodeIfPresent(String.self, forKey: .keyIdentifier)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        self.commonCommands = try container.decodeIfPresent([CommonCommandItem].self, forKey: .commonCommands) ?? []
    }

    func apply(to server: ServerConfig) {
        server.name = name
        server.host = host
        server.port = port
        server.username = username
        server.authType = authType
        server.keyIdentifier = keyIdentifier
        server.tags = tags
        server.lastConnectedAt = lastConnectedAt
    }

    func makeServerConfig() -> ServerConfig {
        let config = ServerConfig(
            name: name,
            host: host,
            port: port,
            username: username,
            authType: authType,
            keyIdentifier: keyIdentifier,
            tags: tags
        )
        config.lastConnectedAt = lastConnectedAt
        return config
    }
}

struct CommonCommandItem: Codable {
    var command: String

    init(record: CommandRecord) {
        self.command = record.command
    }

    init(command: String) {
        self.command = command
    }
}

extension JSONEncoder {
    static var serverListEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var serverListDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
