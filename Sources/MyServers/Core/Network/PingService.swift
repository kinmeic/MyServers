import Foundation
import Network

private final class LockedBool: @unchecked Sendable {
    private var _value = false
    private let lock = NSLock()

    var value: Bool {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

enum PingResult: Equatable {
    case latency(ms: Double)
    case timeout
}

@MainActor
@Observable
final class PingService {
    private var timer: Timer?

    var results: [UUID: PingResult] = [:]

    private func singlePing(host: String, port: Int) async -> Double? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            let start = CFAbsoluteTimeGetCurrent()
            let resumed = LockedBool()

            connection.stateUpdateHandler = { state in
                guard !resumed.value else { return }
                switch state {
                case .ready:
                    resumed.value = true
                    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    connection.cancel()
                    continuation.resume(returning: elapsed)
                case .failed:
                    resumed.value = true
                    connection.cancel()
                    continuation.resume(returning: nil)
                case .cancelled:
                    if !resumed.value {
                        resumed.value = true
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(for: .seconds(5))
                guard !resumed.value else { return }
                resumed.value = true
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }

    func ping(host: String, port: Int) async -> PingResult {
        var samples: [Double] = []

        for _ in 0..<3 {
            if let ms = await singlePing(host: host, port: port) {
                samples.append(ms)
            }
        }

        if samples.isEmpty {
            return .timeout
        }

        samples.sort()
        return .latency(ms: samples[samples.count / 2])
    }

    func startTimer(hosts: @Sendable @escaping () -> [(UUID, String, Int)]) {
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
        timer?.fire()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
