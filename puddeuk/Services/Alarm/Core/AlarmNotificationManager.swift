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

    private init() {
        self.scheduler = AlarmSchedulerFactory.shared.createScheduler()

        // iOS 26+ AlarmKit 사용 시 기존 Legacy 알림 모두 제거
        if AlarmSchedulerFactory.shared.isAlarmKitAvailable {
            Task {
                await self.removeAllLegacyNotifications()
            }
        }
    }

    /// iOS 26에서 기존 UNUserNotificationCenter 알림 모두 제거
    private func removeAllLegacyNotifications() async {
        let pending = await center.pendingNotificationRequests()

        if !pending.isEmpty {
            center.removeAllPendingNotificationRequests()
            Logger.alarm.info("🗑️ [Manager] iOS 26 AlarmKit 사용 - Legacy 알림 모두 제거: \(pending.count)개")
        }
    }


    @discardableResult
    func requestAuthorization() async -> Bool {
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
    }


    func scheduleAlarm(_ alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            await cancelAlarm(alarm)
            return
        }

        Logger.alarm.info("🔔 [Manager] 알람 예약 시작: \(alarm.timeString) - 스케줄러 타입: \(type(of: self.scheduler))")
        try await self.scheduler.scheduleAlarm(alarm)
        await self.scheduler.logPendingNotifications()
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        try await scheduler.scheduleSnooze(minutes: minutes, audioFileName: audioFileName)
    }


    func cancelAlarm(_ alarm: Alarm) async {
        await scheduler.cancelAlarm(alarm)
    }

    func cancelAllAlarms() async {
        await scheduler.cancelAllAlarms()
    }

    func cancelAlarmChain(alarmId: String) async {
        let pendingRequests = await center.pendingNotificationRequests()
        let deliveredNotifications = await center.deliveredNotifications()

        let pendingIdentifiers = pendingRequests
            .map { $0.identifier }
            .filter { $0.hasPrefix(alarmId) }

        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(alarmId) }

        if !pendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
            Logger.notification.info("체인 알림 취소됨 (pending): \(alarmId), 개수: \(pendingIdentifiers.count)")
        }

        if !deliveredIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            Logger.notification.info("체인 알림 취소됨 (delivered): \(alarmId), 개수: \(deliveredIdentifiers.count)")
        }
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
        await scheduler.logPendingNotifications()
    }
}
