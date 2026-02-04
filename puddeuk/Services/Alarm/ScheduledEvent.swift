import Foundation

/// Represents a single notification in the chain
struct ScheduledEvent: Comparable, Sendable {
    let id: String
    let alarmId: UUID
    let fireDate: Date
    let chainIndex: Int
    let priority: ScheduledEventPriority
    var isScheduled: Bool

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.fireDate < rhs.fireDate
    }
}
