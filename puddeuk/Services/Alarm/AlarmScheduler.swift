import Foundation
import UserNotifications
import OSLog

final class AlarmScheduler {
    static let shared = AlarmScheduler()

    private let center = UNUserNotificationCenter.current()
    private let soundService = AlarmSoundService.shared
    private let chainCoordinator = AlarmChainCoordinator.shared

    private init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        // Use queue manager for scheduling
        NotificationQueueManager.shared.incrementQueueVersion()
        try await NotificationQueueManager.shared.rebuildQueue()

        // If alarm is within 48h, schedule immediately
        if let nextFire = alarm.nextFireDate,
           Date().distance(to: nextFire) < 48 * 3600 {
            try await NotificationQueueManager.shared.scheduleNext64()
        }

        Logger.alarm.info("알람 스케줄링 성공 (큐 시스템): \(alarm.title)")
    }

    func cancelAlarm(_ alarm: Alarm) async {
        // Remove from queue manager
        await NotificationQueueManager.shared.removeAlarm(alarmId: alarm.id)

        // Also remove from iOS using chain coordinator
        chainCoordinator.cancelAlarmChain(alarmId: alarm.id.uuidString)

        // Refill available slots
        try? await NotificationQueueManager.shared.scheduleNext64()

        Logger.alarm.info("알람 취소 완료: \(alarm.title)")
    }

    // Legacy methods kept for snooze and testing
    func scheduleAlarm_Legacy(_ alarm: Alarm) async throws {
        if alarm.repeatDays.isEmpty {
            try await scheduleSingleAlarm(alarm)
        } else {
            try await scheduleRepeatingAlarm(alarm)
        }
    }

    func scheduleSingleAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("단일 알람 스케줄링 시작: \(alarm.title)")

        guard let triggerDate = nextAlarmDate(for: alarm) else {
            throw AlarmNotificationError.invalidAlarmDate
        }

        logAlarmSchedule(alarm: alarm, triggerDate: triggerDate)

        let dynamicInterval = chainCoordinator.calculateChainInterval(for: alarm.audioFileName)

        for chainIndex in 0..<chainCoordinator.chainCount {
            let chainTriggerDate = triggerDate.addingTimeInterval(dynamicInterval * Double(chainIndex))
            let content = notificationContent(for: alarm, chainIndex: chainIndex)

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: chainTriggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = "\(alarm.id.uuidString)-chain-\(chainIndex)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
        }

        Logger.alarm.info("알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString)")
    }

    func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("반복 알람 스케줄링 시작: \(alarm.title)")

        let dynamicInterval = chainCoordinator.calculateChainInterval(for: alarm.audioFileName)

        for day in alarm.repeatDays {
            for chainIndex in 0..<chainCoordinator.chainCount {
                let content = notificationContent(for: alarm, chainIndex: chainIndex)

                var components = DateComponents()
                components.weekday = day + 1
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.second = Int(dynamicInterval) * chainIndex

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(alarm.id.uuidString)-\(day)-chain-\(chainIndex)"

                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await center.add(request)
            }
        }
        Logger.alarm.info("반복 알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString)")
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        let snoozeId = UUID().uuidString
        let baseInterval = TimeInterval(minutes * 60)

        let dynamicInterval = chainCoordinator.calculateChainInterval(for: audioFileName)

        for chainIndex in 0..<chainCoordinator.chainCount {
            let content = UNMutableNotificationContent()
            content.title = "스누즈 알람"
            content.body = "알람 시간입니다"
            content.sound = soundService.notificationSound(for: audioFileName)
            content.categoryIdentifier = "ALARM"  // Notification Actions 사용
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "alarmId": "snooze-\(snoozeId)",
                "audioFileName": audioFileName ?? "",
                "title": "스누즈 알람",
                "chainIndex": chainIndex
            ]

            let triggerInterval = baseInterval + (dynamicInterval * Double(chainIndex))
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: triggerInterval,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "snooze-\(snoozeId)-chain-\(chainIndex)",
                content: content,
                trigger: trigger
            )

            try await center.add(request)
        }

        Logger.alarm.info("스누즈 알람 예약됨: \(minutes)분 후 (체인 \(self.chainCoordinator.chainCount)개)")
    }

    func notificationContent(for alarm: Alarm, chainIndex: Int = 0) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요!"
        content.sound = soundService.notificationSound(for: alarm.audioFileName)
        content.categoryIdentifier = "ALARM"  // Notification Actions 사용
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title,
            "chainIndex": chainIndex
        ]
        return content
    }

    func nextAlarmDate(for alarm: Alarm) -> Date? {
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
}
