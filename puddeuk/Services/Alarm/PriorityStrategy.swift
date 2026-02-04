import Foundation

/// Calculates priority and chain count based on time-to-fire
protocol PriorityStrategy {
    func calculatePriority(for date: Date, from referenceDate: Date) -> ScheduledEventPriority
    func determineChainCount(for priority: ScheduledEventPriority) -> Int
}

enum ScheduledEventPriority: Int, Comparable, Sendable {
    case low = 0        // 7+ days: 2-chain
    case medium = 1     // 2-7 days: 4-chain
    case high = 2       // 24-48h: 8-chain
    case critical = 3   // <24h: 8-chain

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Time-based priority strategy: closer alarms get higher priority and more chains
final class TimeBasedPriorityStrategy: PriorityStrategy, Sendable {
    func calculatePriority(for date: Date, from referenceDate: Date = Date()) -> ScheduledEventPriority {
        let hoursUntil = date.timeIntervalSince(referenceDate) / 3600

        switch hoursUntil {
        case ..<24:
            return .critical  // <24h: highest priority
        case 24..<48:
            return .high      // 24-48h: high priority
        case 48..<168:
            return .medium    // 2-7 days: medium priority
        default:
            return .low       // 7+ days: low priority
        }
    }

    func determineChainCount(for priority: ScheduledEventPriority) -> Int {
        switch priority {
        case .critical, .high:
            return 8  // Full coverage for imminent alarms
        case .medium:
            return 4  // Moderate coverage
        case .low:
            return 2  // Minimal coverage for distant alarms
        }
    }
}
