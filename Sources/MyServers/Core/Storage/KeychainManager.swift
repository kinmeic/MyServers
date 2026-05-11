import Foundation

/// Password storage using a file in Application Support.
/// Avoids macOS Keychain system prompts for unsigned/development builds.
enum KeychainManager {
    private static let service = "com.myservers.password"

    private static var storageDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MyServers/passwords", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for serverId: UUID) -> URL {
        storageDir.appendingPathComponent(serverId.uuidString)
    }

    static func savePassword(_ password: String, for serverId: UUID) {
        let data = Data(password.utf8)
        // Simple base64 encoding to avoid plaintext on disk
        let encoded = data.base64EncodedData()
        try? encoded.write(to: fileURL(for: serverId), options: .atomic)
    }

    static func getPassword(for serverId: UUID) -> String? {
        let url = fileURL(for: serverId)
        guard let encoded = try? Data(contentsOf: url),
              let data = Data(base64Encoded: encoded),
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return password
    }

    static func deletePassword(for serverId: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: serverId))
    }
}
