import Foundation

enum AlarmConfiguration {
    // 오디오 녹음 설정
    static let maxNotificationSoundDuration: TimeInterval = 30.0
    static let maxRecordingDuration: TimeInterval = 25.0
    static let recordingWarningThreshold: TimeInterval = 5.0
    static let audioSampleRate: Double = 44100.0
    static let audioBitDepth: Int = 16
}
