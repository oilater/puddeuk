import Foundation
import UserNotifications
import AVFoundation
import SwiftData
import UIKit
import Combine
import OSLog
import AudioToolbox

final class AlarmNotificationService: NSObject, ObservableObject {

    static let shared = AlarmNotificationService()

    @Published var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    private var currentAlarmURL: URL?
    private var currentAudioFileName: String?
    private(set) var currentAlarmId: String?

    private var vibrationTimer: Timer?
    private var isVibrationActive = false

    private override init() {
        super.init()
        setupNotificationDelegate()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            Logger.audio.error("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }

    func startAlarmWithFileName(_ fileName: String, alarmId: String? = nil) {
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
            } else {
                Logger.audio.error("알람 재생 실패: play() returned false")
                isAlarmPlaying = true
            }
        } catch {
            Logger.audio.error("알람 재생 실패: \(url.lastPathComponent) - \(error.localizedDescription)")
            isAlarmPlaying = true
        }
    }

    func stopAlarm() async {
        alarmPlayer?.stop()
        alarmPlayer = nil

        if let alarmId = currentAlarmId {
            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
        }

        currentAlarmURL = nil
        currentAudioFileName = nil
        currentAlarmId = nil
        isAlarmPlaying = false
    }

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

        Task {
            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
        }

        if !isAlarmPlaying {
            if let fileName = audioFileName, !fileName.isEmpty {
                startAlarmWithFileName(fileName, alarmId: alarmId)
            } else {
                isAlarmPlaying = true
                currentAlarmId = alarmId
            }

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
            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
            await stopAlarm()
            await MainActor.run {
                LiveActivityManager.shared.endCurrentActivity()
            }
            try? await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: 5,
                audioFileName: audioFileName
            )
            return

        case "DISMISS_ACTION":
            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
            await stopAlarm()
            await MainActor.run {
                LiveActivityManager.shared.endCurrentActivity()
            }
            return

        case UNNotificationDismissActionIdentifier:
            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
            return

        default:

            await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

            await MainActor.run {
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
    }

    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }


    func startVibration() {
        guard !isVibrationActive else { return }
        isVibrationActive = true
        vibratePattern()

        vibrationTimer = Timer.scheduledTimer(
            withTimeInterval: AlarmConfiguration.vibrationInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self = self, self.isVibrationActive else {
                timer.invalidate()
                return
            }
            self.vibratePattern()
        }
    }

    func stopVibration() {
        isVibrationActive = false
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    private func vibratePattern() {
        for i in 0..<AlarmConfiguration.vibrationRepeatCount {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (AlarmConfiguration.vibrationPatternDelay * Double(i))
            ) { [weak self] in
                guard let self = self, self.isVibrationActive else { return }
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

extension AlarmNotificationService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isAlarmPlaying {
            playAlarm()
        }
    }
}
