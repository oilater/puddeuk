import Foundation
import SwiftData
import UserNotifications
import OSLog

/// UNUserNotificationCenter-based scheduler for iOS 17-25
/// Wraps existing AlarmScheduler (legacy) to conform to AlarmScheduling protocol
final class UNNotificationScheduler: AlarmScheduling, @unchecked Sendable {
    private let legacyScheduler = AlarmScheduler.shared
    private let center = UNUserNotificationCenter.current()

    init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("[UNNotification] 알람 스케줄링 시작: \(alarm.title)")

        guard alarm.isEnabled else {
            await cancelAlarm(alarm)
            return
        }

        // Use existing AlarmScheduler logic
        try await legacyScheduler.scheduleAlarm(alarm)

        await logPendingNotifications()

        Logger.alarm.info("[UNNotification] 알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString)")
    }

    func cancelAlarm(_ alarm: Alarm) async {
        Logger.alarm.info("[UNNotification] 알람 취소 시작: \(alarm.title)")

        // Use existing AlarmScheduler logic
        await legacyScheduler.cancelAlarm(alarm)

        Logger.alarm.info("[UNNotification] 알람 취소 완료: \(alarm.title)")
    }

    func cancelAllAlarms() async {
        Logger.alarm.info("[UNNotification] 모든 알람 취소 시작")

        center.removeAllPendingNotificationRequests()

        Logger.alarm.info("[UNNotification] 모든 알람 취소 완료")
    }

    func scheduleSnooze(minutes: Int, audioFileName: String?) async throws {
        Logger.alarm.info("[UNNotification] 스누즈 알람 예약: \(minutes)분 후")

        // Use existing AlarmScheduler logic
        try await legacyScheduler.scheduleSnooze(minutes: minutes, audioFileName: audioFileName)

        Logger.alarm.info("[UNNotification] 스누즈 알람 예약 완료")
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            Logger.alarm.info("[UNNotification] 알림 권한: \(granted ? "허용됨" : "거부됨")")
            await logAuthorizationStatus()
            return granted
        } catch {
            Logger.alarm.error("[UNNotification] 알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    func logPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        Logger.alarm.debug("[UNNotification] 현재 스케줄된 알림 개수: \(requests.count)")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for request in requests {
            let timeString = formatTrigger(request.trigger, formatter: formatter)
            Logger.alarm.debug("[UNNotification] 알림: \(request.content.title) - \(timeString)")
        }
    }

    // MARK: - Private Helpers

    private func logAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        Logger.alarm.debug(
            "[UNNotification] 권한 상태: \(settings.authorizationStatus.rawValue), 알림 허용: \(settings.authorizationStatus == .authorized), 사운드: \(settings.soundSetting.rawValue)"
        )
    }

    private func formatTrigger(_ trigger: UNNotificationTrigger?, formatter: DateFormatter) -> String {
        switch trigger {
        case let calendarTrigger as UNCalendarNotificationTrigger:
            if let date = Calendar.current.date(from: calendarTrigger.dateComponents) {
                return formatter.string(from: date)
            }
            let hour = calendarTrigger.dateComponents.hour ?? 0
            let minute = calendarTrigger.dateComponents.minute ?? 0
            return String(format: "%02d:%02d", hour, minute)

        case let intervalTrigger as UNTimeIntervalNotificationTrigger:
            return "\(Int(intervalTrigger.timeInterval))초 후"

        default:
            return "알 수 없음"
        }
    }
}
