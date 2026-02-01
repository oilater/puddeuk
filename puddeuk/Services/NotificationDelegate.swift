import Foundation
import UserNotifications
import SwiftData

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    var modelContext: ModelContext?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 알림 수신 (포그라운드): \(notification.request.content.title)")

        if let alarmId = extractAlarmId(from: notification) {
            showAlarmView(alarmId: alarmId)
        }

        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 알림 탭됨: \(response.notification.request.content.title)")

        if let alarmId = extractAlarmId(from: response.notification) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAlarmView(alarmId: alarmId)
            }
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
            print("❌ ModelContext가 설정되지 않음")
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
            print("❌ 알람 찾기 실패: \(error)")
        }
    }
}
