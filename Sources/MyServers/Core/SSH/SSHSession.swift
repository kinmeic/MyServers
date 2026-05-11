import Foundation
import Citadel
import NIOCore
import NIOSSH

/// Sendable configuration extracted from ServerConfig.
struct SSHConnectionInfo: Sendable {
    let host: String
    let port: Int
    let username: String
    let password: String
}

/// Manages a single interactive SSH session using Citadel's PTY API.
/// Keeps the connection alive in a background Task until `disconnect()` is called.
@available(macOS 15.0, *)
actor SSHSession {
    private let info: SSHConnectionInfo
    nonisolated(unsafe) private var client: SSHClient?
    nonisolated(unsafe) private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Error>?
    private var onData: (@Sendable (Data) -> Void)?
    private var onDisconnect: (@Sendable () -> Void)?
    private var bufferedData: [Data] = []

    init(info: SSHConnectionInfo) {
        self.info = info
    }

    /// Establish SSH connection and open an interactive PTY shell.
    func connect() async throws {
        print("[SSHSession] Connecting to \(info.host):\(info.port)")
        let settings = SSHClientSettings(
            host: info.host,
            port: info.port,
            authenticationMethod: { [self] in .passwordBased(username: self.info.username, password: self.info.password) },
            hostKeyValidator: .acceptAnything()
        )

        let client = try await SSHClient.connect(to: settings)
        print("[SSHSession] TCP+SSH handshake complete")
        self.client = client

        let cols = 80
        let rows = 24

        let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )

        let disconnectHandler = onDisconnect

        connectionTask = Task {
            try await client.withPTY(pty) { [weak self] (inbound: TTYOutput, outbound: TTYStdinWriter) in
                self?.stdinWriter = outbound

                for try await output in inbound {
                    switch output {
                    case .stdout(let buffer):
                        let bytes = buffer.getBytes(at: 0, length: buffer.readableBytes) ?? []
                        await self?.deliver(Data(bytes))
                    case .stderr(let buffer):
                        let bytes = buffer.getBytes(at: 0, length: buffer.readableBytes) ?? []
                        await self?.deliver(Data(bytes))
                    }
                }
            }

            await MainActor.run {
                disconnectHandler?()
            }
        }
    }

    /// Send user keystrokes to the remote shell.
    func send(_ data: Data) async {
        let writer = stdinWriter
        guard let writer else { return }
        let buffer = ByteBuffer(data: data)
        try? await writer.write(buffer)
    }

    /// Resize the remote PTY.
    func resize(cols: Int, rows: Int) async {
        // Citadel's withPTY does not expose dynamic resize yet.
        // When supported, send SSHChannelRequestEvent.WindowChangeRequest here.
    }

    /// Close the SSH connection and cancel the background read loop.
    func disconnect() async {
        connectionTask?.cancel()
        connectionTask = nil
        stdinWriter = nil

        let client = self.client
        self.client = nil
        try? await client?.close()
    }

    func setDataHandler(_ handler: @escaping @Sendable (Data) -> Void) async {
        self.onData = handler
        let buffered = bufferedData
        bufferedData.removeAll()
        for data in buffered {
            await MainActor.run {
                handler(data)
            }
        }
    }

    func setDisconnectHandler(_ handler: @escaping @Sendable () -> Void) {
        self.onDisconnect = handler
    }

    private func deliver(_ data: Data) async {
        if let handler = onData {
            await MainActor.run {
                handler(data)
            }
        } else {
            bufferedData.append(data)
        }
    }
}
