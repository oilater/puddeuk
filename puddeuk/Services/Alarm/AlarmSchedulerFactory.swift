import Foundation
import SwiftData
import OSLog

final class AlarmSchedulerFactory {
    static let shared = AlarmSchedulerFactory()

    private init() {}

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
