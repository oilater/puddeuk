import Foundation
import SwiftUI
import SwiftData
import Combine
import AVFoundation
import UserNotifications
import OSLog

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var activeAlarm: Alarm?
    @Published var showAlarmView = false
    @Published var showMissionCompleteView = false

    @Published var notificationTitle: String?
    @Published var notificationAudioFileName: String?

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func showAlarm(_ alarm: Alarm) {
        DispatchQueue.main.async {
            self.activeAlarm = alarm
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
            self.showAlarmView = true
        }
    }

    func showAlarmFromNotification(title: String, audioFileName: String?) {
        DispatchQueue.main.async {
            self.activeAlarm = nil
            self.notificationTitle = title
            self.notificationAudioFileName = audioFileName
            self.showAlarmView = true
        }
    }

    func dismissAlarm() {
        DispatchQueue.main.async {
            self.showAlarmView = false
            self.showMissionCompleteView = false
            self.activeAlarm = nil
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
        }
    }

    func showMissionComplete() {
        DispatchQueue.main.async {
            self.showAlarmView = false
            self.activeAlarm = nil
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showMissionCompleteView = true
            }
        }
    }

    func dismissMissionComplete() {
        DispatchQueue.main.async {
            self.showMissionCompleteView = false
        }
    }

    // MARK: - Background Audio Playback (iOS 17-25 Legacy)

    /// Notification에서 알람 처리 (willPresent / didReceive)
    func handleAlarmNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        guard let alarmIdString = userInfo["alarmId"] as? String else {
            Logger.alarm.error("❌ [AlarmManager] alarmId 없음")
            return
        }

        let title = userInfo["title"] as? String ?? "알람"
        let audioFileName = userInfo["audioFileName"] as? String

        Logger.alarm.info("⏰ [AlarmManager] 알람 처리 시작: \(title)")

        // 1. 오디오 재생
        if let audioFileName = audioFileName, !audioFileName.isEmpty {
            playAlarmAudio(fileName: audioFileName)
        }

        // 2. AlarmView 표시
        showAlarmFromNotification(title: title, audioFileName: audioFileName)

        // 3. Live Activity 시작
        startLiveActivity(alarmId: alarmIdString, title: title, audioFileName: audioFileName)
    }

    /// AVAudioPlayer로 오디오 재생 (무음 모드 무시)
    private func playAlarmAudio(fileName: String) {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")
        let audioURL = soundsPath.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            Logger.alarm.error("❌ [AlarmManager] 오디오 파일 없음: \(fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.numberOfLoops = -1  // 무한 반복
            audioPlayer?.volume = 1.0
            audioPlayer?.play()

            Logger.alarm.info("🔊 [AlarmManager] 오디오 재생 시작: \(fileName)")
        } catch {
            Logger.alarm.error("❌ [AlarmManager] 오디오 재생 실패: \(error.localizedDescription)")
        }
    }

    /// 오디오 중지
    func stopAlarmAudio() {
        audioPlayer?.stop()
        audioPlayer = nil

        Logger.alarm.info("🔇 [AlarmManager] 오디오 중지")

        // Background Task 종료
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.endBackgroundTask()
        }
    }

    /// Live Activity 시작
    private func startLiveActivity(alarmId: String, title: String, audioFileName: String?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        let timeString = formatter.string(from: Date())

        LiveActivityManager.shared.startAlarmActivity(
            alarmId: alarmId,
            title: title,
            scheduledTime: timeString,
            audioFileName: audioFileName ?? ""
        )
    }
}
