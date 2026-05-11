import Testing
@testable import MyServers

@Test func serverConfigDefaults() async throws {
    let config = ServerConfig(name: "Test", host: "192.168.1.1", username: "root")
    #expect(config.port == 22)
    #expect(config.authType == .password)
    #expect(config.displayName == "Test")
}

@Test func keychainRoundTrip() async throws {
    let id = UUID()
    KeychainManager.savePassword("secret123", for: id)
    let retrieved = KeychainManager.getPassword(for: id)
    #expect(retrieved == "secret123")
    KeychainManager.deletePassword(for: id)
    #expect(KeychainManager.getPassword(for: id) == nil)
}
