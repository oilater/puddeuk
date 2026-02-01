import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?

    var audioURL: URL?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
        }
    }

    func startRecording() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            startTime = Date()
            audioURL = audioFilename

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                if let startTime = self?.startTime {
                    self?.recordingTime = Date().timeIntervalSince(startTime)
                }
            }

            return audioFilename
        } catch {
            print("녹음 시작 실패: \(error)")
            return nil
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordingTime = 0
        startTime = nil
    }

    func copyAudioFile(from sourceURL: URL, to fileName: String) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return fileName
        } catch {
            print("오디오 파일 복사 실패: \(error)")
            return nil
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("녹음이 성공적으로 완료되지 않았습니다")
        }
    }
}
