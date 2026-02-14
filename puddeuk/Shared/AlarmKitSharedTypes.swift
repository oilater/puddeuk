import Foundation
import AlarmKit
import AppIntents

// MARK: - Alarm Metadata

/// AlarmKit metadata shared between app and widget extension
/// IMPORTANT: This file MUST be included in BOTH targets (app + AlarmWidget)
public struct PuddeukAlarmMetadata: AlarmKit.AlarmMetadata {
    public let createdAt: Date
    public init() { self.createdAt = Date() }
}

// MARK: - Alarm Intent

/// Intent for stopping alarms
/// IMPORTANT: This must be accessible from both app and widget extension
public struct StopAlarmIntent: LiveActivityIntent {
    @Parameter(title: "alarmID")
    public var alarmID: String

    public func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmKit.AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }

    public static var title: LocalizedStringResource = "끄기"

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public init() {
        self.alarmID = ""
    }
}
