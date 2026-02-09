import Foundation
import SwiftData

protocol AlarmScheduling: Sendable {
    func scheduleAlarm(_ alarm: Alarm) async throws

    func cancelAlarm(_ alarm: Alarm) async

    func cancelAllAlarms() async

    func scheduleSnooze(minutes: Int, audioFileName: String?) async throws

    func requestAuthorization() async -> Bool

    func logPendingNotifications() async
}

extension AlarmScheduling {
    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        try await scheduleSnooze(minutes: minutes, audioFileName: audioFileName)
    }
}
