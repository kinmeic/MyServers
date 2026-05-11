import Foundation
import Network

enum PingResult: Equatable {
    case latency(ms: Double)
    case timeout
}

@MainActor
@Observable
final class PingService {
    private var timer: Timer?

    var results: [UUID: PingResult] = [:]

    func ping(host: String, port: Int) async -> PingResult {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            let start = CFAbsoluteTimeGetCurrent()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    connection.cancel()
                    continuation.resume(returning: .latency(ms: elapsed))
                case .failed, .cancelled:
                    connection.cancel()
                    continuation.resume(returning: .timeout)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                connection.cancel()
            }
        }
    }

    func startTimer(hosts: @escaping () -> [(UUID, String, Int)]) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                for (id, host, port) in hosts() {
                    let result = await self.ping(host: host, port: port)
                    self.results[id] = result
                }
            }
        }
        // Fire immediately
        timer?.fire()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
