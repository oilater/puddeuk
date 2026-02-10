import Foundation

enum AlarmConfiguration {
    static let maxNotificationSoundDuration: TimeInterval = 30.0
    static let maxRecordingDuration: TimeInterval = 25.0
    static let recordingWarningThreshold: TimeInterval = 5.0
    static let audioSampleRate: Double = 44100.0
    static let audioBitDepth: Int = 16

    static let defaultSnoozeMinutes = 5

    static let vibrationInterval: TimeInterval = 2.5
    static let vibrationRepeatCount = 3
    static let vibrationPatternDelay: TimeInterval = 0.1

    // 체인 알람 설정
    static let chainCount = 15  // 체인 알람 개수
    static let minAudioDuration: TimeInterval = 1.0  // 최소 오디오 길이
    static let chainGap: TimeInterval = 1.0  // 체인 간 간격 (오디오 길이 + 1초)
}
