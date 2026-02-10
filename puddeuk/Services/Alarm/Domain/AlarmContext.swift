import Foundation
import UserNotifications

struct AlarmContext: Sendable, Equatable {
    let alarmId: String
    let title: String
    let audioFileName: String?
    let scheduledTime: Date

    init(alarm: Alarm) {
        self.alarmId = alarm.id.uuidString
        self.title = alarm.title.isEmpty ? "알람" : alarm.title
        self.audioFileName = alarm.audioFileName
        self.scheduledTime = alarm.nextFireDate ?? Date()
    }

    init(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        self.alarmId = userInfo["alarmId"] as? String ?? ""
        self.title = userInfo["title"] as? String ?? "알람"

        let fileName = userInfo["audioFileName"] as? String
        self.audioFileName = (fileName?.isEmpty == true) ? nil : fileName

        self.scheduledTime = Date()
    }

    init(
        alarmId: String,
        title: String,
        audioFileName: String?,
        scheduledTime: Date = Date()
    ) {
        self.alarmId = alarmId
        self.title = title
        self.audioFileName = audioFileName
        self.scheduledTime = scheduledTime
    }
}
