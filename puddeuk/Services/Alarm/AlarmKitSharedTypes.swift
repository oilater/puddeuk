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

public struct SnoozeAlarmIntent: LiveActivityIntent {
    @Parameter(title: "alarmID")
    public var alarmID: String

    public func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmKit.AlarmManager.shared.countdown(id: uuid)
        }
        return .result()
    }

    public static var title: LocalizedStringResource = "다시 알림"

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public init() {
        self.alarmID = ""
    }
}

public struct PauseAlarmIntent: LiveActivityIntent {
    @Parameter(title: "alarmID")
    public var alarmID: String

    public func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmKit.AlarmManager.shared.pause(id: uuid)
        }
        return .result()
    }

    public static var title: LocalizedStringResource = "일시정지"

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public init() {
        self.alarmID = ""
    }
}

public struct ResumeAlarmIntent: LiveActivityIntent {
    @Parameter(title: "alarmID")
    public var alarmID: String

    public func perform() throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try AlarmKit.AlarmManager.shared.resume(id: uuid)
        }
        return .result()
    }

    public static var title: LocalizedStringResource = "재개"

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public init() {
        self.alarmID = ""
    }
}
