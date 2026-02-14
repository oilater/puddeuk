import Foundation
import AlarmKit
import AppIntents

public struct PuddeukAlarmMetadata: AlarmKit.AlarmMetadata {
    public let createdAt: Date
    public init() { self.createdAt = Date() }
}

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
