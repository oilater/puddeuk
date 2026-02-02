import Foundation
import AVFoundation
import AudioToolbox
import Combine
import OSLog

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    private func getSoundsDirectory() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return libraryPath.appendingPathComponent("Sounds")
    }

    func playAlarmSound(fileName: String) {
        let audioURL = getSoundsDirectory().appendingPathComponent(fileName)

        do {
            try setupAudioSession()
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.delegate = self
            configurePlayer()
            player?.play()
            isPlaying = true
        } catch {
            Logger.audio.error("알람 소리 재생 실패: \(error.localizedDescription)")
            playDefaultSound()
        }
    }

    func playPreview(fileName: String) -> Bool {
        let audioURL = getSoundsDirectory().appendingPathComponent(fileName)

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
            return false
        }
    }

    func playDefaultSound() {
        if let soundURL = Bundle.main.url(forResource: "default_alarm", withExtension: "mp3") {
            do {
                try setupAudioSession()
                player = try AVAudioPlayer(contentsOf: soundURL)
                player?.delegate = self
                configurePlayer()
                player?.play()
                isPlaying = true
            } catch {
                Logger.audio.error("기본 소리 재생 실패: \(error.localizedDescription)")
                playSystemSound()
            }
        } else {
            playSystemSound()
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

    private func playSystemSound() {
        AudioServicesPlaySystemSound(1005)
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
