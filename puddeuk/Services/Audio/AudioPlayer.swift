import Foundation
import AVFoundation
import AudioToolbox
import Combine

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
            print("✅ 알람 소리 재생 시작: \(fileName)")
        } catch {
            print("❌ 알람 소리 재생 실패: \(error)")
            playDefaultSound()
        }
    }

    func playPreview(fileName: String) -> Bool {
        let audioURL = getSoundsDirectory().appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ 미리듣기 파일 없음: \(audioURL.path)")
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
            print("✅ 미리듣기 재생 시작: \(fileName)")
            return true
        } catch {
            print("❌ 미리듣기 재생 실패: \(error)")
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
                print("❌ 기본 소리 재생 실패: \(error)")
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
        // 백그라운드 재생 및 무음 모드에서도 소리 재생 가능하도록 설정
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
            print("오디오 세션 비활성화 실패: \(error)")
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
