import Foundation
import UserNotifications
import AVFoundation
import SwiftData
import UIKit
import Combine
import OSLog

final class AlarmNotificationService: NSObject, ObservableObject {

    static let shared = AlarmNotificationService()

    @Published var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    private var currentAlarmURL: URL?
    private var currentAudioFileName: String?
    private var currentAlarmId: String?

    private override init() {
        super.init()
        setupAudioSession()
        setupNotificationDelegate()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            Logger.audio.info("오디오 세션 설정 완료")
        } catch {
            Logger.audio.error("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }

    func startAlarmWithFileName(_ fileName: String, alarmId: String? = nil) {
        Logger.audio.info("알람 파일 재생 시도: \(fileName)")

        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
            .appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.audio.warning("알람 파일 없음: \(fileName)")
            isAlarmPlaying = true
            currentAlarmId = alarmId
            return
        }

        currentAlarmURL = url
        currentAudioFileName = fileName
        currentAlarmId = alarmId
        playAlarm()
    }

    private func playAlarm() {
        guard let url = currentAlarmURL else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            alarmPlayer?.stop()
            alarmPlayer = nil

            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.delegate = self
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.volume = 1.0
            alarmPlayer?.prepareToPlay()

            let success = alarmPlayer?.play() ?? false
            if success {
                isAlarmPlaying = true
                Logger.audio.info("알람 재생 시작")
            } else {
                Logger.audio.error("알람 재생 실패: play() returned false")
                isAlarmPlaying = true
            }
        } catch {
            Logger.audio.error("알람 재생 실패: \(url.lastPathComponent) - \(error.localizedDescription)")
            isAlarmPlaying = true
        }
    }

    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil

        // 체인 알림 취소
        if let alarmId = currentAlarmId {
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
        }

        currentAlarmURL = nil
        currentAudioFileName = nil
        currentAlarmId = nil
        isAlarmPlaying = false
        Logger.audio.info("알람 중지")
    }

    /// 현재 재생 중인 오디오 파일명 반환
    func getCurrentAudioFileName() -> String? {
        return currentAudioFileName
    }

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
}

extension AlarmNotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"
        let alarmId = userInfo["alarmId"] as? String ?? ""
        let chainIndex = userInfo["chainIndex"] as? Int ?? 0

        Logger.notification.info("알람 도착 (포그라운드): \(title)")

        // 포그라운드에서는 AVAudioPlayer로 재생 + 나머지 체인 알림 취소
        if !isAlarmPlaying {
            if let fileName = audioFileName, !fileName.isEmpty {
                startAlarmWithFileName(fileName, alarmId: alarmId)
            } else {
                isAlarmPlaying = true
                currentAlarmId = alarmId
            }

            // 나머지 체인 알림 취소 (AVAudioPlayer가 무한 재생하므로)
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

            let timeString = getCurrentTimeString()
            Task { @MainActor in
                LiveActivityManager.shared.startAlarmActivity(
                    alarmId: alarmId,
                    title: title,
                    scheduledTime: timeString,
                    audioFileName: audioFileName
                )
            }

            AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        }

        // 첫 번째 알림만 배너 표시, 사운드는 항상 재생 (백업용)
        if chainIndex == 0 {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"
        let alarmId = userInfo["alarmId"] as? String ?? ""

        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            Logger.notification.info("스누즈 액션")
            await MainActor.run {
                // 체인 알림 취소 포함
                AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
                stopAlarm()
                LiveActivityManager.shared.endCurrentActivity()
            }
            // 스누즈 시 같은 오디오 파일로 체인 알림 예약
            try? await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: 5,
                audioFileName: audioFileName
            )
            return

        case "DISMISS_ACTION":
            Logger.notification.info("끄기 액션")
            await MainActor.run {
                // 체인 알림 취소 포함
                AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
                stopAlarm()
                LiveActivityManager.shared.endCurrentActivity()
            }
            return

        default:
            break
        }

        Logger.notification.info("알림 탭 → 앱으로 이동: \(title)")

        await MainActor.run {
            // 나머지 체인 알림 취소 (앱이 포그라운드로 왔으므로 AVAudioPlayer 사용)
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

            if let fileName = audioFileName, !fileName.isEmpty {
                startAlarmWithFileName(fileName, alarmId: alarmId)
            } else {
                isAlarmPlaying = true
                currentAlarmId = alarmId
            }

            let timeString = getCurrentTimeString()
            LiveActivityManager.shared.startAlarmActivity(
                alarmId: alarmId,
                title: title,
                scheduledTime: timeString,
                audioFileName: audioFileName
            )

            AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        }
    }

    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }
}

extension AlarmNotificationService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isAlarmPlaying {
            playAlarm()
        }
    }
}
