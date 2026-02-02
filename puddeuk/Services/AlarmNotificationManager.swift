import Foundation
import UserNotifications
import SwiftData
import OSLog

// MARK: - Error Types

enum AlarmNotificationError: LocalizedError {
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

// MARK: - AlarmNotificationManager

final class AlarmNotificationManager {
    static let shared = AlarmNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let soundService = AlarmSoundService.shared

    // MARK: - Chain Notification Constants
    private let chainCount = AlarmConfiguration.chainCount
    private let chainInterval = AlarmConfiguration.chainInterval

    private init() {}

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            Logger.notification.info("알림 권한: \(granted ? "허용됨" : "거부됨")")
            await logAuthorizationStatus()
            return granted
        } catch {
            Logger.notification.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    func logAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        Logger.notification.debug("알림 권한 상태: \(settings.authorizationStatus.rawValue), 알림 허용: \(settings.authorizationStatus == .authorized), 사운드: \(settings.soundSetting.rawValue)")
    }

    // MARK: - Category Registration

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

    // MARK: - Scheduling

    func scheduleAlarm(_ alarm: Alarm) async throws {
        guard alarm.isEnabled else {
            await cancelAlarm(alarm)
            return
        }

        if alarm.repeatDays.isEmpty {
            try await scheduleSingleAlarm(alarm)
        } else {
            try await scheduleRepeatingAlarm(alarm)
        }
    }

    func scheduleSnooze(minutes: Int = 5, audioFileName: String? = nil) async throws {
        let snoozeId = UUID().uuidString
        let baseInterval = TimeInterval(minutes * 60)

        // 동적 간격 계산
        let dynamicInterval = calculateChainInterval(for: audioFileName)

        // 체인 알림 예약 (동적 간격으로 8개)
        for chainIndex in 0..<chainCount {
            let content = UNMutableNotificationContent()
            content.title = "스누즈 알람"
            content.body = chainIndex == 0 ? "알람 시간입니다" : ""
            content.sound = soundService.notificationSound(for: audioFileName)
            content.categoryIdentifier = "ALARM"
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

        Logger.alarm.info("스누즈 알람 예약됨: \(minutes)분 후 (체인 \(self.chainCount)개)")
    }

    // MARK: - Cancellation

    func cancelAlarm(_ alarm: Alarm) async {
        let identifiers = alarmIdentifiers(for: alarm)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        Logger.alarm.info("알람 취소됨: \(alarm.title)")
    }

    func cancelAllAlarms() async {
        center.removeAllPendingNotificationRequests()
        Logger.alarm.info("모든 알람 취소됨")
    }

    // MARK: - Pending Check

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

    // MARK: - Debug

    func logPendingNotifications() async {
        let requests = await center.pendingNotificationRequests()
        Logger.notification.debug("현재 스케줄된 알림 개수: \(requests.count)")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for request in requests {
            let timeString = formatTrigger(request.trigger, formatter: formatter)
            Logger.notification.debug("알림: \(request.content.title) - \(timeString)")
        }
    }

    // MARK: - Private Methods

    /// 오디오 파일 길이 계산 (파일 크기 기반 - Linear PCM)
    private func calculateAudioDuration(for audioFileName: String?) -> TimeInterval {
        guard let fileName = audioFileName,
              let fileSize = soundService.fileSize(fileName) else {
            return 5.0  // 기본값: 5초
        }

        // Linear PCM 공식: duration = fileSize / (sampleRate × bytesPerSample × channels)
        // sampleRate = 44100, bitDepth = 16 (2 bytes), channels = 1
        let bytesPerSecond = AlarmConfiguration.audioSampleRate * Double(AlarmConfiguration.audioBitDepth / 8)
        let duration = Double(fileSize) / bytesPerSecond

        Logger.alarm.debug("오디오 길이 계산: \(fileName) = \(String(format: "%.1f", duration))초 (\(fileSize) bytes)")
        return max(duration, 1.0)  // 최소 1초
    }

    /// 동적 체인 간격 계산 (1초 텀 유지)
    private func calculateChainInterval(for audioFileName: String?) -> TimeInterval {
        let duration = calculateAudioDuration(for: audioFileName)

        // 전략: 오디오 길이 + 1초 간격 (겹침 없음)
        let interval = duration + 1.0

        Logger.alarm.debug("체인 간격 계산: \(String(format: "%.1f", duration))초 녹음 → \(String(format: "%.1f", interval))초 간격 (1초 텀)")
        return interval
    }

    private func scheduleSingleAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("단일 알람 스케줄링 시작: \(alarm.title)")

        guard let triggerDate = nextAlarmDate(for: alarm) else {
            throw AlarmNotificationError.invalidAlarmDate
        }

        logAlarmSchedule(alarm: alarm, triggerDate: triggerDate)

        // 동적 간격 계산
        let dynamicInterval = calculateChainInterval(for: alarm.audioFileName)

        // 체인 알림 예약 (동적 간격으로 8개)
        for chainIndex in 0..<chainCount {
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
        await logPendingNotifications()
    }

    private func scheduleRepeatingAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("반복 알람 스케줄링 시작: \(alarm.title)")

        // 동적 간격 계산
        let dynamicInterval = calculateChainInterval(for: alarm.audioFileName)

        for day in alarm.repeatDays {
            // 체인 알림 예약 (동적 간격으로 8개)
            for chainIndex in 0..<chainCount {
                let content = notificationContent(for: alarm, chainIndex: chainIndex)

                var components = DateComponents()
                components.weekday = day + 1
                components.hour = alarm.hour
                components.minute = alarm.minute
                // 체인 간격을 초 단위로 추가
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

    private func notificationContent(for alarm: Alarm, chainIndex: Int = 0) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = chainIndex == 0 ? "알람 시간입니다. 탭하여 끄기" : ""
        content.sound = soundService.notificationSound(for: alarm.audioFileName)
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title,
            "chainIndex": chainIndex
        ]
        return content
    }

    private func alarmIdentifiers(for alarm: Alarm) -> [String] {
        var identifiers: [String] = []

        if alarm.repeatDays.isEmpty {
            // 단일 알람: chain-0 ~ chain-7
            for chainIndex in 0..<chainCount {
                identifiers.append("\(alarm.id.uuidString)-chain-\(chainIndex)")
            }
        } else {
            // 반복 알람: 각 요일별로 chain-0 ~ chain-7
            for day in alarm.repeatDays {
                for chainIndex in 0..<chainCount {
                    identifiers.append("\(alarm.id.uuidString)-\(day)-chain-\(chainIndex)")
                }
            }
        }

        return identifiers
    }

    /// 특정 알람 ID의 모든 체인 알림 취소 (외부에서 호출 가능)
    func cancelAlarmChain(alarmId: String) {
        var identifiers: [String] = []

        // 단일 알람 체인
        for chainIndex in 0..<chainCount {
            identifiers.append("\(alarmId)-chain-\(chainIndex)")
        }

        // 반복 알람 체인 (모든 요일)
        for day in 0..<7 {
            for chainIndex in 0..<chainCount {
                identifiers.append("\(alarmId)-\(day)-chain-\(chainIndex)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        Logger.alarm.info("체인 알림 취소됨: \(alarmId)")
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

    private func formatTrigger(_ trigger: UNNotificationTrigger?, formatter: DateFormatter) -> String {
        switch trigger {
        case let calendarTrigger as UNCalendarNotificationTrigger:
            if let date = Calendar.current.date(from: calendarTrigger.dateComponents) {
                return formatter.string(from: date)
            }
            let hour = calendarTrigger.dateComponents.hour ?? 0
            let minute = calendarTrigger.dateComponents.minute ?? 0
            return String(format: "%02d:%02d", hour, minute)

        case let intervalTrigger as UNTimeIntervalNotificationTrigger:
            return "\(Int(intervalTrigger.timeInterval))초 후"

        default:
            return "알 수 없음"
        }
    }
}
