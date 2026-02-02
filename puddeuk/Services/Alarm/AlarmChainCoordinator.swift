import Foundation
import UserNotifications
import OSLog

/// 체인 알림 관리 전용 클래스
/// - 오디오 길이 계산
/// - 체인 간격 계산
/// - 체인 알림 취소
final class AlarmChainCoordinator {
    static let shared = AlarmChainCoordinator()

    private let soundService = AlarmSoundService.shared
    private let center = UNUserNotificationCenter.current()

    let chainCount = AlarmConfiguration.chainCount
    let chainInterval = AlarmConfiguration.chainInterval

    private init() {}

    /// 오디오 파일의 실제 재생 시간 계산
    func calculateAudioDuration(for audioFileName: String?) -> TimeInterval {
        guard let fileName = audioFileName,
              let fileSize = soundService.fileSize(fileName) else {
            return 5.0
        }

        let bytesPerSecond = AlarmConfiguration.audioSampleRate * Double(AlarmConfiguration.audioBitDepth / 8)
        let duration = Double(fileSize) / bytesPerSecond

        Logger.alarm.debug("오디오 길이 계산: \(fileName) = \(String(format: "%.1f", duration))초 (\(fileSize) bytes)")
        return max(duration, 1.0)
    }

    /// 체인 알림 간격 계산 (오디오 길이 + 1초 텀)
    func calculateChainInterval(for audioFileName: String?) -> TimeInterval {
        let duration = calculateAudioDuration(for: audioFileName)
        let interval = duration + 1.0

        Logger.alarm.debug("체인 간격 계산: \(String(format: "%.1f", duration))초 녹음 → \(String(format: "%.1f", interval))초 간격 (1초 텀)")
        return interval
    }

    /// 체인 알림 전체 취소
    func cancelAlarmChain(alarmId: String) {
        var identifiers: [String] = []

        // 단일 알람 체인
        for chainIndex in 0..<chainCount {
            identifiers.append("\(alarmId)-chain-\(chainIndex)")
        }

        // 반복 알람 체인 (모든 요일)
        for day in 0..<7 {
            for chainIndex in 0..<chainCount {
                identifiers.append("\(alarmId)-\(day)-chain-\(chainIndex)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        Logger.alarm.info("체인 알림 취소됨: \(alarmId)")
    }

    /// 알람의 모든 체인 식별자 생성
    func buildChainIdentifiers(for alarm: Alarm) -> [String] {
        var identifiers: [String] = []

        if alarm.repeatDays.isEmpty {
            // 단일 알람
            for chainIndex in 0..<chainCount {
                identifiers.append("\(alarm.id.uuidString)-chain-\(chainIndex)")
            }
        } else {
            // 반복 알람
            for day in alarm.repeatDays {
                for chainIndex in 0..<chainCount {
                    identifiers.append("\(alarm.id.uuidString)-\(day)-chain-\(chainIndex)")
                }
            }
        }

        return identifiers
    }
}
