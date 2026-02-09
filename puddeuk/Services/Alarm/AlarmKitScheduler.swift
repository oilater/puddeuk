import Foundation
import SwiftData
import SwiftUI
import OSLog
import AppIntents
import ActivityKit

#if canImport(AlarmKit)
import AlarmKit

/// AlarmKit-based scheduler for iOS 26+
/// Supports custom sounds, Live Activity, and system-level alarms that override silent mode
@available(iOS 26, *)
final class AlarmKitScheduler: AlarmScheduling, @unchecked Sendable {

    // MARK: - Constants

    private enum Constants {
        static let defaultAlarmTitle = "알람"
        static let snoozeTitle = LocalizedStringResource(stringLiteral: "스누즈 알람")
        static let stopButtonText = LocalizedStringResource(stringLiteral: "끄기")
        static let stopButtonIcon = "stop.circle"
        static let alarmTintColor: Color = .blue
        static let snoozeTintColor: Color = .orange
    }

    // MARK: - Properties

    private let alarmManager = AlarmKit.AlarmManager.shared
    private let soundService = AlarmSoundService.shared
    private let soundFileManager = AlarmSoundFileManager.shared

    init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        Logger.alarm.info("[AlarmKit] 알람 스케줄링 시작: \(alarm.title)")

        // 1. Prepare custom sound
        let soundFileName = try await soundFileManager.prepareSoundFile(alarm.audioFileName)

        // 2. Create alarm schedule
        guard let schedule = createSchedule(for: alarm) else {
            throw AlarmNotificationError.invalidAlarmDate
        }

        // 3. Create configuration
        let title = alarm.title.isEmpty ? Constants.defaultAlarmTitle : alarm.title
        let configuration = makeConfiguration(
            schedule: schedule,
            title: title,
            tintColor: Constants.alarmTintColor,
            soundFileName: soundFileName,
            alarmID: alarm.id
        )

        // 4. Schedule the alarm
        _ = try await alarmManager.schedule(id: alarm.id, configuration: configuration)

        Logger.alarm.info("[AlarmKit] 알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString)")
    }

    func cancelAlarm(_ alarm: Alarm) async {
        do {
            try alarmManager.cancel(id: alarm.id)
            Logger.alarm.info("[AlarmKit] 알람 취소됨: \(alarm.title)")
        } catch {
            Logger.alarm.error("[AlarmKit] 알람 취소 실패: \(error.localizedDescription)")
        }
    }

    func cancelAllAlarms() async {
        do {
            let alarms = try alarmManager.alarms
            for alarm in alarms {
                try alarmManager.cancel(id: alarm.id)
            }
            Logger.alarm.info("[AlarmKit] 모든 알람 취소됨")
        } catch {
            Logger.alarm.error("[AlarmKit] 모든 알람 취소 실패: \(error.localizedDescription)")
        }
    }

    func scheduleSnooze(minutes: Int, audioFileName: String?) async throws {
        Logger.alarm.info("[AlarmKit] 스누즈 알람 예약: \(minutes)분 후")

        // 1. Calculate fire date
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let schedule = AlarmKit.Alarm.Schedule.fixed(fireDate)

        // 2. Prepare custom sound
        let soundFileName = try await soundFileManager.prepareSoundFile(audioFileName)

        // 3. Create configuration
        let snoozeId = UUID()
        let configuration = makeConfiguration(
            schedule: schedule,
            title: "스누즈 알람",
            tintColor: Constants.snoozeTintColor,
            soundFileName: soundFileName,
            alarmID: snoozeId
        )

        // 4. Schedule snooze alarm
        _ = try await alarmManager.schedule(id: snoozeId, configuration: configuration)

        Logger.alarm.info("[AlarmKit] 스누즈 알람 예약 완료")
    }

    func requestAuthorization() async -> Bool {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                let granted = state == .authorized
                Logger.alarm.info("[AlarmKit] 권한 요청 결과: \(granted ? "허용됨" : "거부됨")")
                return granted
            } catch {
                Logger.alarm.error("[AlarmKit] 권한 요청 실패: \(error.localizedDescription)")
                return false
            }
        case .authorized:
            Logger.alarm.info("[AlarmKit] 권한 이미 허용됨")
            return true
        case .denied:
            Logger.alarm.warning("[AlarmKit] 권한 거부됨")
            return false
        @unknown default:
            return false
        }
    }

    func logPendingNotifications() async {
        do {
            let alarms = try alarmManager.alarms
            Logger.alarm.debug("[AlarmKit] 현재 스케줄된 알람 개수: \(alarms.count)")

            for alarm in alarms {
                let scheduleString = formatSchedule(alarm.schedule)
                Logger.alarm.debug("[AlarmKit] 알람: ID=\(alarm.id) - \(scheduleString)")
            }
        } catch {
            Logger.alarm.error("[AlarmKit] 알람 목록 조회 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    // MARK: Configuration Factory

    /// Create AlarmConfiguration for scheduling
    private func makeConfiguration(
        schedule: AlarmKit.Alarm.Schedule,
        title: String,
        tintColor: Color,
        soundFileName: String?,
        alarmID: UUID
    ) -> AlarmKit.AlarmManager.AlarmConfiguration<PuddeukAlarmMetadata> {
        let presentation = makePresentation(title: title)
        let attributes = makeAttributes(presentation: presentation, tintColor: tintColor)
        let sound = makeSound(fileName: soundFileName)

        return AlarmKit.AlarmManager.AlarmConfiguration<PuddeukAlarmMetadata>(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarmID.uuidString),
            sound: sound
        )
    }

    /// Create AlertSound from optional file name
    private func makeSound(fileName: String?) -> AlertConfiguration.AlertSound {
        if let fileName = fileName {
            return .named(fileName)
        } else {
            return .default
        }
    }

    /// Create AlarmPresentation from title
    private func makePresentation(title: String) -> AlarmPresentation {
        let localizedTitle = LocalizedStringResource(stringLiteral: title)

        let alert = AlarmPresentation.Alert(
            title: localizedTitle,
            stopButton: AlarmButton(text: Constants.stopButtonText, textColor: .white, systemImageName: Constants.stopButtonIcon)
        )

        return AlarmPresentation(alert: alert)
    }

    /// Create AlarmAttributes with metadata and tint color
    private func makeAttributes(
        presentation: AlarmPresentation,
        tintColor: Color
    ) -> AlarmKit.AlarmAttributes<PuddeukAlarmMetadata> {
        return AlarmKit.AlarmAttributes<PuddeukAlarmMetadata>(
            presentation: presentation,
            metadata: PuddeukAlarmMetadata(),
            tintColor: tintColor
        )
    }

    // MARK: Schedule Helpers

    private func createSchedule(for alarm: puddeuk.Alarm) -> AlarmKit.Alarm.Schedule? {
        let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)

        if alarm.repeatDays.isEmpty {
            // One-time alarm (relative to current date)
            return .relative(.init(time: time, repeats: .never))
        } else {
            // Repeating alarm
            let weekdays = alarm.repeatDays.compactMap { day -> Locale.Weekday? in
                // Convert 0-6 (Sun-Sat) to Locale.Weekday
                switch day {
                case 0: return .sunday
                case 1: return .monday
                case 2: return .tuesday
                case 3: return .wednesday
                case 4: return .thursday
                case 5: return .friday
                case 6: return .saturday
                default: return nil
                }
            }

            return .relative(.init(time: time, repeats: .weekly(weekdays)))
        }
    }

    private func formatSchedule(_ schedule: AlarmKit.Alarm.Schedule?) -> String {
        guard let schedule = schedule else {
            return "알 수 없음"
        }

        switch schedule {
        case .fixed(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)

        case .relative(let relative):
            let timeString = String(format: "%02d:%02d", relative.time.hour, relative.time.minute)

            switch relative.repeats {
            case .never:
                return "\(timeString) (일회성)"
            case .weekly(let weekdays):
                let dayNames = weekdays.map { $0.rawValue }.joined(separator: ", ")
                return "\(timeString) (반복: \(dayNames))"
            @unknown default:
                return timeString
            }

        @unknown default:
            return "알 수 없음"
        }
    }
}

// MARK: - AlarmMetadata

struct PuddeukAlarmMetadata: AlarmKit.AlarmMetadata {
    let createdAt: Date

    init() {
        self.createdAt = Date()
    }
}

// MARK: - App Intents

import AppIntents

@available(iOS 26, *)
struct StopAlarmIntent: LiveActivityIntent {
    @Parameter(title: "alarmID")
    var alarmID: String

    func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmKit.AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }

    static var title: LocalizedStringResource = "끄기"
    static var description = IntentDescription("알람을 끕니다")

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}

#else
// Stub implementation for when AlarmKit is not available
@available(iOS 26, *)
final class AlarmKitScheduler: AlarmScheduling, @unchecked Sendable {
    init() {}

    func scheduleAlarm(_ alarm: Alarm) async throws {
        throw AlarmNotificationError.schedulingFailed("AlarmKit not available")
    }

    func cancelAlarm(_ alarm: Alarm) async {}

    func cancelAllAlarms() async {}

    func scheduleSnooze(minutes: Int, audioFileName: String?) async throws {
        throw AlarmNotificationError.schedulingFailed("AlarmKit not available")
    }

    func requestAuthorization() async -> Bool {
        return false
    }

    func logPendingNotifications() async {}
}
#endif
