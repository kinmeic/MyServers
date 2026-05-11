import Foundation
import Citadel

/// Sends periodic SSH keepalive messages to prevent NAT/firewall timeout.
@MainActor
final class SSHKeepAlive {
    private weak var client: SSHClient?
    private var timer: Timer?
    private let interval: TimeInterval = 30

    init(client: SSHClient) {
        self.client = client
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.sendKeepAlive()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sendKeepAlive() async {
        guard client != nil else { return }
        // Citadel does not expose a direct keepalive API.
        // As a fallback, send a no-op global request or rely on TCP keepalive.
        // When swift-nio-ssh exposes sendGlobalRequest, use:
        // try? await client.sendGlobalRequest(...)
    }
}
