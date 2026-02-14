import Foundation
import SwiftData
import SwiftUI
import AlarmKit

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
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarmTitle),
            stopButton: AlarmButton(
                text: "끄기",
                textColor: .white,
                systemImageName: "stop.circle"
            )
        )

        let presentation = AlarmPresentation(alert: alert)

        let attributes = AlarmKit.AlarmAttributes<PuddeukAlarmMetadata>(
            presentation: presentation,
            metadata: PuddeukAlarmMetadata(),
            tintColor: .blue
        )

        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarm.id.uuidString)
        )

        _ = try await alarmManager.schedule(id: alarm.id, configuration: configuration)
    }

    static func cancelAlarm(_ alarm: Alarm) async throws {
        try alarmManager.cancel(id: alarm.id)
    }
}

// MARK: - Error Types

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
