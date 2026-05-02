import Foundation

enum RetryPolicy {
    static let delays: [TimeInterval] = [0.1, 0.2, 0.4, 0.8, 1.6]
    static let maxAttempts = 5
    static let staleThreshold: TimeInterval = 60.0

    static func delay(for attempt: Int) -> TimeInterval? {
        guard attempt > 0 && attempt <= delays.count else { return nil }
        return delays[attempt - 1]
    }
}
