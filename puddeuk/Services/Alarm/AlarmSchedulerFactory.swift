import Foundation
import SwiftData
import OSLog

/// Factory for creating appropriate alarm scheduler based on iOS version
final class AlarmSchedulerFactory {
    /// Shared singleton instance
    static let shared = AlarmSchedulerFactory()

    private init() {}

    /// Create appropriate scheduler for current iOS version
    /// - Returns: AlarmKitScheduler for iOS 26+, UNNotificationScheduler for iOS 17-25
    func createScheduler() -> any AlarmScheduling {
        if #available(iOS 26, *) {
            #if canImport(AlarmKit)
            Logger.alarm.info("[Factory] AlarmKitScheduler 생성 (iOS 26+)")
            return AlarmKitScheduler()
            #else
            Logger.alarm.warning("[Factory] AlarmKit 사용 불가, UNNotificationScheduler 사용")
            return UNNotificationScheduler()
            #endif
        } else {
            Logger.alarm.info("[Factory] AlarmScheduler 생성 (iOS 17-25)")
            return AlarmScheduler.shared
        }
    }

    /// Check if AlarmKit is available on current device
    /// - Returns: True if running iOS 26+ and AlarmKit is available
    var isAlarmKitAvailable: Bool {
        if #available(iOS 26, *) {
            #if canImport(AlarmKit)
            return true
            #else
            return false
            #endif
        } else {
            return false
        }
    }

    /// Get human-readable description of current scheduler
    var schedulerDescription: String {
        if #available(iOS 26, *) {
            #if canImport(AlarmKit)
            return "AlarmKit (iOS 26+)"
            #else
            return "UNUserNotificationCenter (iOS 26, AlarmKit 사용 불가)"
            #endif
        } else {
            return "UNUserNotificationCenter (iOS 17-25)"
        }
    }
}
