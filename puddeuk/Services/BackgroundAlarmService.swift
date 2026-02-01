import Foundation
import UserNotifications
import AVFoundation
import SwiftData
import UIKit
import Combine

final class AlarmNotificationService: NSObject, ObservableObject {

    static let shared = AlarmNotificationService()

    @Published var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    private var currentAlarmURL: URL?
    private var currentAudioFileName: String?

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
            print("✅ 오디오 세션 설정 완료")
        } catch {
            print("❌ 오디오 세션 설정 실패:", error)
        }
    }

    func startAlarmWithFileName(_ fileName: String) {
        print("🎵 알람 파일 재생 시도: \(fileName)")

        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
            .appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 파일 없음: \(fileName)")
            isAlarmPlaying = true
            return
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            print("📁 파일: \(fileName), \(size) bytes")
        }

        currentAlarmURL = url
        currentAudioFileName = fileName
        playAlarm()
    }

    private func playAlarm() {
        guard let url = currentAlarmURL else { return }

        print("🎵 재생 시도: \(url.lastPathComponent)")

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
                print("🎵 알람 재생 시작 ✅")
            } else {
                print("❌ 알람 재생 실패: play() returned false")
                isAlarmPlaying = true
            }
        } catch {
            print("❌ 알람 재생 실패: \(url.lastPathComponent)")
            print("   오류: \(error)")
            isAlarmPlaying = true
        }
    }

    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        currentAlarmURL = nil
        currentAudioFileName = nil
        isAlarmPlaying = false
        print("🔇 알람 중지")
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

        print("🔔 알람 (포그라운드): \(title)")

        if let fileName = audioFileName, !fileName.isEmpty {
            startAlarmWithFileName(fileName)
        } else {
            isAlarmPlaying = true
        }

        AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"

        print("🔔 알림 탭 → 앱으로 이동: \(title)")

        await MainActor.run {
            if let fileName = audioFileName, !fileName.isEmpty {
                startAlarmWithFileName(fileName)
            } else {
                isAlarmPlaying = true
            }
            AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        }
    }
}

extension AlarmNotificationService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isAlarmPlaying {
            print("⚠️ 알람 재시작")
            playAlarm()
        }
    }
}
