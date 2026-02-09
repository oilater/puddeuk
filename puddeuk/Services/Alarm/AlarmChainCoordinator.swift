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

    /// 체인 알림 전체 취소 (실제 존재하는 알림만 조회해서 안전하게 삭제)
    func cancelAlarmChain(alarmId: String) async {
        // 실제 pending notifications 조회
        let pendingRequests = await center.pendingNotificationRequests()
        let deliveredNotifications = await center.deliveredNotifications()

        // alarmId로 시작하는 모든 알림 식별자 필터링
        let pendingIdentifiers = pendingRequests
            .map { $0.identifier }
            .filter { $0.hasPrefix(alarmId) }

        let deliveredIdentifiers = deliveredNotifications
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(alarmId) }

        // 실제 존재하는 알림만 삭제 (메모리 누수 방지)
        if !pendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
            Logger.alarm.info("체인 알림 취소됨 (pending): \(alarmId), 개수: \(pendingIdentifiers.count)")
        }

        if !deliveredIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            Logger.alarm.info("체인 알림 취소됨 (delivered): \(alarmId), 개수: \(deliveredIdentifiers.count)")
        }

        if pendingIdentifiers.isEmpty && deliveredIdentifiers.isEmpty {
            Logger.alarm.debug("취소할 체인 알림 없음: \(alarmId)")
        }
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
