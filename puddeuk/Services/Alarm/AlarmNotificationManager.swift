import Foundation
import UserNotifications
import SwiftData
import OSLog

enum AlarmNotificationError: LocalizedError {
    case authorizationDenied
    case schedulingFailed(String)
    case invalidAlarmDate
    case alarmNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "알림 권한이 거부되었습니다"
        case .schedulingFailed(let reason):
            return "알람 예약 실패: \(reason)"
        case .invalidAlarmDate:
            return "알람 시간을 계산할 수 없습니다"
        case .alarmNotFound(let id):
            return "알람을 찾을 수 없습니다: \(id)"
        }
    }
}

/// 알림 관리 코디네이터
/// - 권한 관리
/// - 알림 카테고리 등록
/// - 스케줄링/취소 조율
final class AlarmNotificationManager {
    static let shared = AlarmNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let scheduler = AlarmScheduler.shared
    private let chainCoordinator = AlarmChainCoordinator.shared

    private init() {}

    // MARK: - 권한 관리

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            Logger.notification.info("알림 권한: \(granted ? "허용됨" : "거부됨")")
            await logAuthorizationStatus()
            return granted
        } catch {
            Logger.notification.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    func logAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        Logger.notification.debug("알림 권한 상태: \(settings.authorizationStatus.rawValue), 알림 허용: \(settings.authorizationStatus == .authorized), 사운드: \(settings.soundSetting.rawValue)")
    }

    func registerNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "5분 후",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "끄기",
            options: [.destructive]
        )

        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([alarmCategory])
        Logger.notification.info("알림 카테고리 등록 완료")
    }

    // MARK: - 스케줄링 (Scheduler로 위임)

    func scheduleAlarm(_ alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            await cancelAlarm(alarm)
            return
        }

        try await scheduler.scheduleAlarm(alarm)
        await logPendingNotifications()
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        try await scheduler.scheduleSnooze(minutes: minutes, audioFileName: audioFileName)
    }

    // MARK: - 취소

    func cancelAlarm(_ alarm: Alarm) async {
        let identifiers = chainCoordinator.buildChainIdentifiers(for: alarm)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        Logger.alarm.info("알람 취소됨: \(alarm.title)")
    }

    func cancelAllAlarms() async {
        center.removeAllPendingNotificationRequests()
        Logger.alarm.info("모든 알람 취소됨")
    }

    func cancelAlarmChain(alarmId: String) {
        chainCoordinator.cancelAlarmChain(alarmId: alarmId)
    }

    // MARK: - 디버깅

    func checkPendingAlarm(modelContext: ModelContext) async {
        let notifications = await center.deliveredNotifications()

        await MainActor.run {
            for notification in notifications {
                guard let alarmIdString = notification.request.content.userInfo["alarmId"] as? String,
                      let alarmId = UUID(uuidString: alarmIdString) else {
                    continue
                }

                let descriptor = FetchDescriptor<Alarm>(
                    predicate: #Predicate { $0.id == alarmId }
                )

                do {
                    let foundAlarms = try modelContext.fetch(descriptor)
                    if let alarm = foundAlarms.first, alarm.isEnabled {
                        AlarmManager.shared.showAlarm(alarm)
                        center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                        break
                    }
                } catch {
                    Logger.alarm.error("알람 찾기 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    func logPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        Logger.notification.debug("현재 스케줄된 알림 개수: \(requests.count)")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for request in requests {
            let timeString = formatTrigger(request.trigger, formatter: formatter)
            Logger.notification.debug("알림: \(request.content.title) - \(timeString)")
        }
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
