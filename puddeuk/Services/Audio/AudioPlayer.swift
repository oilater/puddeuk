import Foundation
import AVFoundation
import AudioToolbox
import Combine
import OSLog

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    func playPreview(fileName: String) -> Bool {
        guard let soundsDirectory = try? FileManager.default.getSoundsDirectory() else {
            Logger.audio.error("Sounds 디렉토리 접근 실패")
            return false
        }
        let audioURL = soundsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            Logger.audio.warning("미리듣기 파일 없음")
            return false
        }

        do {
            try setupAudioSession()
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.delegate = self
            player?.numberOfLoops = 0
            player?.volume = 1.0
            player?.play()
            isPlaying = true
            return true
        } catch {
            Logger.audio.error("미리듣기 재생 실패: \(error.localizedDescription)")
            AnalyticsManager.shared.logPlaybackFailed(message: error.localizedDescription)
            return false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        deactivateAudioSession()
    }

    private func setupAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func configurePlayer() {
        player?.numberOfLoops = -1
        player?.volume = 1.0
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Logger.audio.warning("오디오 세션 비활성화 실패: \(error.localizedDescription)")
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        deactivateAudioSession()
    }
}
