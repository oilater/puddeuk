import Foundation
import UserNotifications
import OSLog
import SwiftData

final class AlarmScheduler: AlarmScheduling {
    static let shared = AlarmScheduler()

    private let center = UNUserNotificationCenter.current()
    private let soundFileManager = AlarmSoundFileManager.shared

    let chainCount = AlarmConfiguration.chainCount

    private init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        NotificationQueueManager.shared.incrementQueueVersion()
        try await NotificationQueueManager.shared.rebuildQueue()

        if let nextFire = alarm.nextFireDate,
           Date().distance(to: nextFire) < 48 * 3600 {
            try await NotificationQueueManager.shared.scheduleNext60()
        }

        Logger.alarm.info("알람 스케줄링 성공 (큐 시스템): \(alarm.title)")
    }

    func cancelAlarm(_ alarm: Alarm) async {
        await NotificationQueueManager.shared.removeAlarm(alarmId: alarm.id)

        await cancelAlarmChain(alarmId: alarm.id.uuidString)
        await cancelAllSnoozeAlarms()

        try? await NotificationQueueManager.shared.scheduleNext60()

        Logger.alarm.info("알람 취소 완료: \(alarm.title)")
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

        let dynamicInterval = self.calculateChainInterval(for: alarm.audioFileName)

        for chainIndex in 0..<self.chainCount {
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

        let dynamicInterval = self.calculateChainInterval(for: alarm.audioFileName)

        for day in alarm.repeatDays {
            for chainIndex in 0..<self.chainCount {
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

        let dynamicInterval = self.calculateChainInterval(for: audioFileName)

        for chainIndex in 0..<self.chainCount {
            let content = UNMutableNotificationContent()
            content.title = "스누즈 알람"
            content.body = "알람 시간입니다"
            content.sound = soundFileManager.notificationSound(for: audioFileName)
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

        Logger.alarm.info("스누즈 알람 예약됨: \(minutes)분 후 (체인 \(self.self.chainCount)개)")
    }

    func notificationContent(for alarm: Alarm, chainIndex: Int = 0) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요!"
        content.sound = soundFileManager.notificationSound(for: alarm.audioFileName)
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

    // MARK: - Chain Alarm Management (from AlarmChainCoordinator)

    /// 오디오 파일의 실제 재생 시간 계산
    func calculateAudioDuration(for audioFileName: String?) -> TimeInterval {
        guard let fileName = audioFileName,
              let fileSize = soundFileManager.fileSize(fileName) else {
            return 5.0
        }

        let bytesPerSecond = AlarmConfiguration.audioSampleRate * Double(AlarmConfiguration.audioBitDepth / 8)
        let duration = Double(fileSize) / bytesPerSecond

        Logger.alarm.debug("오디오 길이 계산: \(fileName) = \(String(format: "%.1f", duration))초 (\(fileSize) bytes)")
        return max(duration, 1.0)
    }

    /// 체인 알림 간격 계산 (오디오 길이 + 1초 텀)
    func calculateChainInterval(for audioFileName: String?) -> TimeInterval {
        let duration = calculateAudioDuration(for: audioFileName)
        let interval = duration + 1.0

        Logger.alarm.debug("체인 간격 계산: \(String(format: "%.1f", duration))초 녹음 → \(String(format: "%.1f", interval))초 간격 (1초 텀)")
        return interval
    }

    /// 체인 알림 전체 취소 (실제 존재하는 알림만 조회해서 안전하게 삭제)
    func cancelAlarmChain(alarmId: String) async {
        // 실제 pending notifications 조회
        let pendingRequests = await center.pendingNotificationRequests()
        let deliveredNotifications = await center.deliveredNotifications()

        // alarmId로 시작하는 모든 알림 식별자 필터링
        let pendingIdentifiers = pendingRequests
            .map { $0.identifier }
            .filter { $0.hasPrefix(alarmId) }

        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(alarmId) }

        // 실제 존재하는 알림만 삭제 (메모리 누수 방지)
        if !pendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
            Logger.alarm.info("체인 알림 취소됨 (pending): \(alarmId), 개수: \(pendingIdentifiers.count)")
        }

        if !deliveredIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            Logger.alarm.info("체인 알림 취소됨 (delivered): \(alarmId), 개수: \(deliveredIdentifiers.count)")
        }

        if pendingIdentifiers.isEmpty && deliveredIdentifiers.isEmpty {
            Logger.alarm.debug("취소할 체인 알림 없음: \(alarmId)")
        }
    }

    /// 알람의 모든 체인 식별자 생성
    func buildChainIdentifiers(for alarm: Alarm) -> [String] {
        var identifiers: [String] = []

        if alarm.repeatDays.isEmpty {
            // 단일 알람
            for chainIndex in 0..<chainCount {
                identifiers.append("\(alarm.id.uuidString)-chain-\(chainIndex)")
            }
        } else {
            // 반복 알람
            for day in alarm.repeatDays {
                for chainIndex in 0..<chainCount {
                    identifiers.append("\(alarm.id.uuidString)-\(day)-chain-\(chainIndex)")
                }
            }
        }

        return identifiers
    }

    // MARK: - AlarmScheduling Protocol (iOS 17-25)

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

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for request in requests {
            Logger.alarm.debug("알림: \(request.content.title)")
        }
    }
}
