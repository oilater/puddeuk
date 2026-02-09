import Foundation
import UserNotifications
import SwiftData
import OSLog

enum AlarmNotificationError: LocalizedError, Sendable {
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

final class AlarmNotificationManager: @unchecked Sendable {
    static let shared = AlarmNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let scheduler: any AlarmScheduling
    private let legacyScheduler = AlarmScheduler.shared  // Legacy direct access
    private let chainCoordinator = AlarmChainCoordinator.shared

    private init() {
        // Use factory to get appropriate scheduler
        self.scheduler = AlarmSchedulerFactory.shared.createScheduler()
        Logger.notification.info("AlarmNotificationManager 초기화: \(AlarmSchedulerFactory.shared.schedulerDescription)")
    }


    @discardableResult
    func requestAuthorization() async -> Bool {
        // Use scheduler's authorization request
        return await scheduler.requestAuthorization()
    }

    func logAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        Logger.notification.debug("알림 권한 상태: \(settings.authorizationStatus.rawValue), 알림 허용: \(settings.authorizationStatus == .authorized), 사운드: \(settings.soundSetting.rawValue)")
    }

    @MainActor
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


    func scheduleAlarm(_ alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            await cancelAlarm(alarm)
            return
        }

        // Use new scheduler interface
        try await scheduler.scheduleAlarm(alarm)
        await scheduler.logPendingNotifications()
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        // Use new scheduler interface
        try await scheduler.scheduleSnooze(minutes: minutes, audioFileName: audioFileName)
    }


    func cancelAlarm(_ alarm: Alarm) async {
        // Use new scheduler interface
        await scheduler.cancelAlarm(alarm)
    }

    func cancelAllAlarms() async {
        // Use new scheduler interface
        await scheduler.cancelAllAlarms()
    }

    func cancelAlarmChain(alarmId: String) async {
        await chainCoordinator.cancelAlarmChain(alarmId: alarmId)
    }


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
        // Use new scheduler interface
        await scheduler.logPendingNotifications()
    }
}
