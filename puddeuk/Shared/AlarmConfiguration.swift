import Foundation

enum AlarmConfiguration {
    /// @deprecated: Use PriorityStrategy.determineChainCount() instead
    /// Legacy chain count (no longer used in queue system)
    /// Current system uses priority-based chain count: Critical/High=15, Medium=8, Low=4
    static let chainCount = 8

    static let chainInterval: TimeInterval = 26.5

    static let maxNotificationSoundDuration: TimeInterval = 30.0
    static let maxRecordingDuration: TimeInterval = 25.0
    static let recordingWarningThreshold: TimeInterval = 5.0
    static let audioSampleRate: Double = 44100.0
    static let audioBitDepth: Int = 16

    static let defaultSnoozeMinutes = 5

    static let vibrationInterval: TimeInterval = 2.5
    static let vibrationRepeatCount = 3
    static let vibrationPatternDelay: TimeInterval = 0.1
}
