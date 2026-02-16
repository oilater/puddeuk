import Foundation
import SwiftData
import SwiftUI
import AlarmKit
import ActivityKit

/// Simple helper for AlarmKit scheduling operations
/// Shared between AddAlarmViewModel, ContentView, and AlarmRow
@MainActor
struct AlarmKitHelper {

    private static let alarmManager = AlarmKit.AlarmManager.shared

    static func scheduleAlarm(_ alarm: Alarm) async throws {
        switch alarmManager.authorizationState {
        case .authorized:
            break
        case .notDetermined:
            let state = try await alarmManager.requestAuthorization()
            guard state == .authorized else {
                throw AlarmKitError.authorizationDenied
            }
        case .denied:
            throw AlarmKitError.authorizationDenied
        @unknown default:
            throw AlarmKitError.unknown
        }

        let time = AlarmKit.Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let schedule: AlarmKit.Alarm.Schedule

        if alarm.repeatDays.isEmpty {
            schedule = .relative(.init(time: time, repeats: .never))
        } else {
            let weekdays = alarm.repeatDays.compactMap { day -> Locale.Weekday? in
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
            schedule = .relative(.init(time: time, repeats: .weekly(weekdays)))
        }

        let alarmTitle = alarm.title.isEmpty ? "알람" : alarm.title
        let snoozeEnabled = alarm.snoozeInterval != nil && (alarm.snoozeInterval ?? 0) > 0

        let alert: AlarmPresentation.Alert
        if snoozeEnabled {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alarmTitle),
                stopButton: AlarmButton(
                    text: "끄기",
                    textColor: .white,
                    systemImageName: "stop.circle"
                ),
                secondaryButton: AlarmButton(
                    text: "다시 알림",
                    textColor: .black,
                    systemImageName: "repeat"
                ),
                secondaryButtonBehavior: .countdown
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: alarmTitle),
                stopButton: AlarmButton(
                    text: "끄기",
                    textColor: .white,
                    systemImageName: "stop.circle"
                )
            )
        }

        let presentation: AlarmPresentation
        if snoozeEnabled {
            let countdownContent = AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: alarmTitle),
                pauseButton: AlarmButton(
                    text: "일시정지",
                    textColor: .black,
                    systemImageName: "pause.fill"
                )
            )
            let pausedContent = AlarmPresentation.Paused(
                title: LocalizedStringResource(stringLiteral: "일시정지됨"),
                resumeButton: AlarmButton(
                    text: "재개",
                    textColor: .black,
                    systemImageName: "play.fill"
                )
            )
            presentation = AlarmPresentation(
                alert: alert,
                countdown: countdownContent,
                paused: pausedContent
            )
        } else {
            presentation = AlarmPresentation(alert: alert)
        }

        let attributes = AlarmKit.AlarmAttributes<PuddeukAlarmMetadata>(
            presentation: presentation,
            metadata: PuddeukAlarmMetadata(),
            tintColor: .blue
        )

        let sound: AlertConfiguration.AlertSound
        if let audioFileName = alarm.audioFileName {
            sound = .named(audioFileName)
        } else {
            sound = .default
        }

        let countdownDuration: AlarmKit.Alarm.CountdownDuration? = if snoozeEnabled,
            let interval = alarm.snoozeInterval {
            .init(preAlert: nil, postAlert: TimeInterval(interval * 60))
        } else {
            nil
        }

        let secondaryIntent: SnoozeAlarmIntent? = snoozeEnabled
            ? SnoozeAlarmIntent(alarmID: alarm.id.uuidString)
            : nil

        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarm.id.uuidString),
            secondaryIntent: secondaryIntent,
            sound: sound
        )

        _ = try await alarmManager.schedule(id: alarm.id, configuration: configuration)
    }

    static func cancelAlarm(_ alarm: Alarm) async throws {
        try alarmManager.cancel(id: alarm.id)
    }
}

enum AlarmKitError: LocalizedError {
    case authorizationDenied
    case unknown

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "AlarmKit 권한이 필요합니다. 설정에서 활성화해 주세요."
        case .unknown:
            return "알 수 없는 오류가 발생했습니다."
        }
    }
}
