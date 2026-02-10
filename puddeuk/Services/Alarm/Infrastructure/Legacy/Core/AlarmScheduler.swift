import Foundation
import UserNotifications
import OSLog
import SwiftData

final class AlarmScheduler: AlarmScheduling {
    static let shared = AlarmScheduler()

    private let center = UNUserNotificationCenter.current()
    private let soundFileManager = AlarmSoundFileManager.shared

    private init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        if alarm.repeatDays.isEmpty {
            try await scheduleSingleAlarm(alarm)
        } else {
            try await scheduleRepeatingAlarm(alarm)
        }
    }

    func cancelAlarm(_ alarm: Alarm) async {
        if alarm.repeatDays.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        } else {
            let identifiers = alarm.repeatDays.map { "\(alarm.id.uuidString)-\($0)" }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        await cancelAllSnoozeAlarms()
        Logger.alarm.info("알람 취소됨: \(alarm.id.uuidString)")
    }

    func cancelAllSnoozeAlarms() async {
        let pending = await center.pendingNotificationRequests()
        let snoozeIdentifiers = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix("snooze-") }

        guard !snoozeIdentifiers.isEmpty else { return }

        center.removePendingNotificationRequests(withIdentifiers: snoozeIdentifiers)
        Logger.alarm.info("스누즈 알람 취소됨: \(snoozeIdentifiers.count)개")
    }

    private func scheduleSingleAlarm(_ alarm: Alarm) async throws {
        guard let triggerDate = nextAlarmDate(for: alarm) else {
            throw AlarmNotificationError.invalidAlarmDate
        }

        logAlarmSchedule(alarm: alarm, triggerDate: triggerDate)

        let content = notificationContent(for: alarm)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        Logger.alarm.info("단일 알람 예약: \(alarm.id.uuidString) - \(triggerDate)")
    }

    private func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
        for day in alarm.repeatDays {
            let content = notificationContent(for: alarm)

            var components = DateComponents()
            components.weekday = day + 1
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "\(alarm.id.uuidString)-\(day)"

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
            Logger.alarm.info("반복 알람 예약: \(identifier) - 요일 \(day)")
        }
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        let snoozeId = UUID().uuidString
        let interval = TimeInterval(minutes * 60)

        let content = UNMutableNotificationContent()
        content.title = "스누즈 알람"
        content.body = "알람 시간입니다"
        content.sound = soundFileManager.notificationSound(for: audioFileName)
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": "snooze-\(snoozeId)",
            "audioFileName": audioFileName ?? "",
            "title": "스누즈 알람"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "snooze-\(snoozeId)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        Logger.alarm.info("스누즈 알람 예약: \(minutes)분 후")
    }

    private func notificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요!"
        content.sound = soundFileManager.notificationSound(for: alarm.audioFileName)
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title
        ]
        return content
    }

    private func nextAlarmDate(for alarm: Alarm) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0

        guard var triggerDate = calendar.date(from: components) else {
            return nil
        }

        if triggerDate <= now {
            triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
        }

        return triggerDate
    }

    private func logAlarmSchedule(alarm: Alarm, triggerDate: Date) {
        let interval = triggerDate.timeIntervalSince(Date())
        let minutes = Int(interval / 60)
        Logger.alarm.debug("알람 예약 시간: \(triggerDate), 남은 시간: \(minutes)분")
    }

    func cancelAllAlarms() async {
        center.removeAllPendingNotificationRequests()
        Logger.alarm.info("모든 알람 취소 완료")
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            Logger.alarm.info("알림 권한: \(granted ? "허용됨" : "거부됨")")
            return granted
        } catch {
            Logger.alarm.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    func logPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        Logger.alarm.debug("현재 스케줄된 알림 개수: \(requests.count)")

        for request in requests {
            Logger.alarm.debug("알림: \(request.content.title)")
        }
    }
}
