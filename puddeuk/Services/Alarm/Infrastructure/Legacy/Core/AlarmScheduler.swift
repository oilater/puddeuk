import Foundation
import UserNotifications
import OSLog
import SwiftData

final class AlarmScheduler: AlarmScheduling {
    static let shared = AlarmScheduler()

    private let center = UNUserNotificationCenter.current()
    private let soundFileManager = AlarmSoundFileManager.shared

    // 체인 설정
    private let chainCount = AlarmConfiguration.chainCount  // 15개 체인

    private init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        // 기존 알람이 있다면 먼저 제거
        await cancelAlarm(alarm)

        // 체인을 포함한 알람 스케줄링
        if alarm.repeatDays.isEmpty {
            try await scheduleSingleAlarm(alarm)
        } else {
            try await scheduleRepeatingAlarm(alarm)
        }
    }

    func cancelAlarm(_ alarm: Alarm) async {
        // 모든 관련 노티피케이션 식별자 수집
        var identifiers: [String] = []

        if alarm.repeatDays.isEmpty {
            // 단일 알람: 기본 + 체인
            identifiers.append(alarm.id.uuidString)
            for i in 0..<chainCount {
                identifiers.append("\(alarm.id.uuidString)-chain-\(i)")
            }
        } else {
            // 반복 알람: 각 요일별 기본 + 체인
            for day in alarm.repeatDays {
                identifiers.append("\(alarm.id.uuidString)-\(day)")
                for i in 0..<chainCount {
                    identifiers.append("\(alarm.id.uuidString)-\(day)-chain-\(i)")
                }
            }
        }

        // 모든 관련 노티피케이션 제거
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        await cancelAllSnoozeAlarms()
        Logger.alarm.info("알람 취소됨: \(alarm.id.uuidString) - 체인 포함 \(identifiers.count)개")
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

        // 오디오 길이 기반 체인 간격 계산
        let chainInterval = calculateChainInterval(for: alarm.audioFileName)

        // 기본 알람 스케줄
        let content = notificationContent(for: alarm, chainIndex: nil)
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

        // 체인 노티피케이션 스케줄 (오디오 길이 + 1초 간격)
        for i in 0..<chainCount {
            let chainFireDate = triggerDate.addingTimeInterval(TimeInterval(i + 1) * chainInterval)
            let chainContent = notificationContent(for: alarm, chainIndex: i)
            let chainComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: chainFireDate
            )
            let chainTrigger = UNCalendarNotificationTrigger(dateMatching: chainComponents, repeats: false)

            let chainRequest = UNNotificationRequest(
                identifier: "\(alarm.id.uuidString)-chain-\(i)",
                content: chainContent,
                trigger: chainTrigger
            )

            try await center.add(chainRequest)
        }

        Logger.alarm.info("단일 알람 예약: \(alarm.id.uuidString) - \(triggerDate) (체인 \(self.chainCount)개, 간격 \(String(format: "%.1f", chainInterval))초)")
    }

    private func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
        // 오디오 길이 기반 체인 간격 계산
        let chainInterval = calculateChainInterval(for: alarm.audioFileName)

        for day in alarm.repeatDays {
            // 기본 알람 스케줄
            let content = notificationContent(for: alarm, chainIndex: nil)

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

            // 체인 노티피케이션 스케줄 (오디오 길이 + 1초 간격)
            for i in 0..<chainCount {
                let totalSeconds = Int((TimeInterval(i + 1) * chainInterval))
                let additionalMinutes = totalSeconds / 60
                let remainingSeconds = totalSeconds % 60

                var chainComponents = DateComponents()
                chainComponents.weekday = day + 1
                chainComponents.hour = alarm.hour
                chainComponents.minute = alarm.minute + additionalMinutes
                chainComponents.second = remainingSeconds

                // 분이 60을 넘으면 시간으로 올림
                if chainComponents.minute! >= 60 {
                    chainComponents.hour! += chainComponents.minute! / 60
                    chainComponents.minute! = chainComponents.minute! % 60

                    // 시간이 24를 넘으면 다음 날로
                    if chainComponents.hour! >= 24 {
                        chainComponents.hour! = chainComponents.hour! % 24
                        chainComponents.weekday! += 1
                        if chainComponents.weekday! > 7 {
                            chainComponents.weekday! = 1
                        }
                    }
                }

                let chainTrigger = UNCalendarNotificationTrigger(dateMatching: chainComponents, repeats: true)
                let chainIdentifier = "\(alarm.id.uuidString)-\(day)-chain-\(i)"

                let chainContent = notificationContent(for: alarm, chainIndex: i)
                let chainRequest = UNNotificationRequest(
                    identifier: chainIdentifier,
                    content: chainContent,
                    trigger: chainTrigger
                )

                try await center.add(chainRequest)
            }

            Logger.alarm.info("반복 알람 예약: \(identifier) - 요일 \(day) (체인 \(self.chainCount)개, 간격 \(String(format: "%.1f", chainInterval))초)")
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

    private func notificationContent(for alarm: Alarm, chainIndex: Int?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요!"
        content.sound = soundFileManager.notificationSound(for: alarm.audioFileName)
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title,
            "isChainNotification": chainIndex != nil,
            "chainIndex": chainIndex ?? -1
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

    // MARK: - Audio Duration Calculation

    /// 오디오 파일의 실제 재생 시간 계산
    private func calculateAudioDuration(for audioFileName: String?) -> TimeInterval {
        guard let fileName = audioFileName,
              let fileSize = soundFileManager.fileSize(fileName) else {
            return 5.0  // 기본값: 5초
        }

        // 오디오 길이 = 파일크기 / (샘플레이트 * 비트뎁스/8)
        let bytesPerSecond = AlarmConfiguration.audioSampleRate * Double(AlarmConfiguration.audioBitDepth / 8)
        let duration = Double(fileSize) / bytesPerSecond

        Logger.alarm.debug("오디오 길이 계산: \(fileName) = \(String(format: "%.1f", duration))초 (\(fileSize) bytes)")
        return max(duration, AlarmConfiguration.minAudioDuration)
    }

    /// 체인 알림 간격 계산 (오디오 길이 + 1초 텀)
    private func calculateChainInterval(for audioFileName: String?) -> TimeInterval {
        let duration = calculateAudioDuration(for: audioFileName)
        let interval = duration + AlarmConfiguration.chainGap

        Logger.alarm.debug("체인 간격 계산: \(String(format: "%.1f", duration))초 녹음 → \(String(format: "%.1f", interval))초 간격")
        return interval
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
