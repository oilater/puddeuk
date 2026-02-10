import Foundation
import AVFoundation
import UIKit
import Combine
import OSLog

@MainActor
final class AlarmAudioPlayer: ObservableObject {
    static let shared = AlarmAudioPlayer()

    @Published private(set) var isPlaying = false

    private var audioPlayer: AVAudioPlayer?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private init() {}


    func play(fileName: String, loop: Bool = true) {
        setupAudioSession()
        startBackgroundTask()

        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")
        let audioURL = soundsPath.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            Logger.alarm.error("❌ [AudioPlayer] 파일 없음: \(fileName)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.numberOfLoops = loop ? -1 : 0
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            isPlaying = true

            Logger.alarm.info("🔊 [AudioPlayer] 재생 시작: \(fileName) (loop: \(loop))")
        } catch {
            Logger.alarm.error("❌ [AudioPlayer] 재생 실패: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        endBackgroundTask()

        Logger.alarm.info("🔇 [AudioPlayer] 재생 중지")
    }


    private func setupAudioSession() {
        Task {
            do {
                let session = AVAudioSession.sharedInstance()
                try await session.setCategory(
                    .playback,
                    mode: .default,
                    options: []
                )
                try await session.setActive(true)

                Logger.alarm.info("🔊 [AudioPlayer] AVAudioSession 활성화 완료")
            } catch {
                Logger.alarm.error("❌ [AudioPlayer] AVAudioSession 설정 실패: \(error.localizedDescription)")
            }
        }
    }


    private func startBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }

        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            Logger.alarm.warning("⏱️ [AudioPlayer] Background Task 시간 만료")
            self?.endBackgroundTask()
        }

        let timeRemaining = UIApplication.shared.backgroundTimeRemaining
        if timeRemaining != .infinity && timeRemaining < Double(Int.max) {
            Logger.alarm.info("⏱️ [AudioPlayer] Background Task 시작 - 남은 시간: \(Int(timeRemaining))초")
        }
    }

    func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid

        Logger.alarm.info("✅ [AudioPlayer] Background Task 종료")
    }
}
