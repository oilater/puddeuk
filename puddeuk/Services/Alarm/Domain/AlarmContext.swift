import Foundation

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
