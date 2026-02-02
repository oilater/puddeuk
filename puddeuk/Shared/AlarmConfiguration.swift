import Foundation

enum AlarmConfiguration {
    // MARK: - Chain Notification
    /// 체인 알림 개수 (26.5초 × 8 = 212초 = 약 3분 30초 커버)
    static let chainCount = 8
    /// 체인 알림 간격 (초) - 30초 사운드와 3.5초 겹침
    static let chainInterval: TimeInterval = 26.5

    // MARK: - Audio
    /// iOS 알림 사운드 최대 길이 (초)
    static let maxNotificationSoundDuration: TimeInterval = 30.0
    /// 오디오 샘플 레이트 (Hz)
    static let audioSampleRate: Double = 44100.0
    /// 오디오 비트 깊이
    static let audioBitDepth: Int = 16

    // MARK: - Snooze
    /// 기본 스누즈 시간 (분)
    static let defaultSnoozeMinutes = 5

    // MARK: - Vibration
    /// 진동 반복 간격 (초)
    static let vibrationInterval: TimeInterval = 2.5
    /// 진동 패턴 반복 횟수 (길게 만들기 위함)
    static let vibrationRepeatCount = 3
    /// 진동 패턴 내 간격 (초)
    static let vibrationPatternDelay: TimeInterval = 0.1
}
