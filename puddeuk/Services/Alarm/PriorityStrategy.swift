import Foundation

protocol PriorityStrategy {
    func calculatePriority(for date: Date, from referenceDate: Date) -> ScheduledEventPriority
    func determineChainCount(for priority: ScheduledEventPriority) -> Int
}

enum ScheduledEventPriority: Int, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

final class TimeBasedPriorityStrategy: PriorityStrategy, Sendable {
    func calculatePriority(for date: Date, from referenceDate: Date = Date()) -> ScheduledEventPriority {
        let hoursUntil = date.timeIntervalSince(referenceDate) / 3600

        switch hoursUntil {
        case ..<24:
            return .critical
        case 24..<48:
            return .high
        case 48..<168:
            return .medium
        default:
            return .low
        }
    }

    func determineChainCount(for priority: ScheduledEventPriority) -> Int {
        switch priority {
        case .critical, .high:
            return 15
        case .medium:
            return 8
        case .low:
            return 4
        }
    }
}
