import Foundation
import UserNotifications
import SwiftData
import OSLog

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    var modelContext: ModelContext?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.notification.info("알림 수신 (포그라운드): \(notification.request.content.title)")

        let userInfo = notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"
        let alarmId = userInfo["alarmId"] as? String ?? ""

        // Live Activity 시작
        let timeString = getCurrentTimeString()
        Task { @MainActor in
            LiveActivityManager.shared.startAlarmActivity(
                alarmId: alarmId,
                title: title,
                scheduledTime: timeString,
                audioFileName: audioFileName
            )
        }

        if let uuid = extractAlarmId(from: notification) {
            showAlarmView(alarmId: uuid)
        }

        // 알림 배너 표시 (액션 버튼 포함)
        completionHandler([.banner, .sound, .list])
    }

    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.notification.info("알림 액션: \(response.actionIdentifier)")

        let userInfo = response.notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String

        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            Logger.notification.info("스누즈 액션 실행")
            AlarmNotificationService.shared.stopAlarm()
            Task {
                try? await AlarmNotificationManager.shared.scheduleSnooze(
                    minutes: 5,
                    audioFileName: audioFileName
                )
            }

        case "DISMISS_ACTION":
            Logger.notification.info("끄기 액션 실행")
            AlarmNotificationService.shared.stopAlarm()
            Task { @MainActor in
                LiveActivityManager.shared.endCurrentActivity()
            }
            AlarmManager.shared.dismissAlarm()

        case UNNotificationDefaultActionIdentifier:
            // 알림 탭 - 알람 화면 보여주기
            if let alarmId = extractAlarmId(from: response.notification) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showAlarmView(alarmId: alarmId)
                }
            }

        default:
            break
        }

        completionHandler()
    }

    private func extractAlarmId(from notification: UNNotification) -> UUID? {
        guard let alarmIdString = notification.request.content.userInfo["alarmId"] as? String else {
            return nil
        }
        return UUID(uuidString: alarmIdString)
    }

    private func showAlarmView(alarmId: UUID) {
        guard let modelContext = modelContext else {
            Logger.alarm.error("ModelContext가 설정되지 않음")
            return
        }

        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmId }
        )

        do {
            let alarms = try modelContext.fetch(descriptor)
            if let alarm = alarms.first {
                AlarmManager.shared.showAlarm(alarm)
            }
        } catch {
            Logger.alarm.error("알람 찾기 실패: \(error.localizedDescription)")
        }
    }
}
