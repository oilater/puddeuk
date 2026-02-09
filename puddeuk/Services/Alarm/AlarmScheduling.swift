import Foundation
import SwiftData

/// Protocol for alarm scheduling implementations
/// Supports both UNUserNotificationCenter (iOS 17-25) and AlarmKit (iOS 26+)
protocol AlarmScheduling: Sendable {
    /// Schedule an alarm with the given configuration
    /// - Parameter alarm: The alarm to schedule
    /// - Throws: AlarmNotificationError if scheduling fails
    func scheduleAlarm(_ alarm: Alarm) async throws

    /// Cancel a scheduled alarm
    /// - Parameter alarm: The alarm to cancel
    func cancelAlarm(_ alarm: Alarm) async

    /// Cancel all scheduled alarms
    func cancelAllAlarms() async

    /// Schedule a snooze alarm
    /// - Parameters:
    ///   - minutes: Number of minutes to snooze (default: 5)
    ///   - audioFileName: Optional custom audio file name
    /// - Throws: AlarmNotificationError if scheduling fails
    func scheduleSnooze(minutes: Int, audioFileName: String?) async throws

    /// Request authorization for alarm scheduling
    /// - Returns: True if authorization granted, false otherwise
    func requestAuthorization() async -> Bool

    /// Log pending notifications for debugging
    func logPendingNotifications() async
}

// Default implementations
extension AlarmScheduling {
    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        try await scheduleSnooze(minutes: minutes, audioFileName: audioFileName)
    }
}
