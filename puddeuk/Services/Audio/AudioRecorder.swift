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

    /// 녹음 완료 콜백
    var onRecordingFinished: ((URL?) -> Void)?

    override init() {
        super.init()
        setupAudioSession()
        createSoundsDirectoryIfNeeded()
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

    private func createSoundsDirectoryIfNeeded() {
        let soundsPath = getSoundsDirectory()
        if !FileManager.default.fileExists(atPath: soundsPath.path) {
            do {
                try FileManager.default.createDirectory(at: soundsPath, withIntermediateDirectories: true)
                print("✅ Library/Sounds 폴더 생성됨")
            } catch {
                print("❌ Library/Sounds 폴더 생성 실패: \(error)")
            }
        }
    }

    private func getSoundsDirectory() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return libraryPath.appendingPathComponent("Sounds")
    }

    func startRecording() -> URL? {
        setupAudioSession()

        let soundsPath = getSoundsDirectory()
        // M4A (ALAC) 형식 사용 - Apple Lossless, 무손실 압축
        let audioFilename = soundsPath.appendingPathComponent("\(UUID().uuidString).m4a")

        // ALAC (Apple Lossless) 형식으로 녹음
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitDepthHintKey: 16
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            isRecording = true
            startTime = Date()
            audioURL = audioFilename

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingTime = Date().timeIntervalSince(startTime)
            }

            print("🎙️ 녹음 시작 (ALAC): \(audioFilename.lastPathComponent)")
            return audioFilename
        } catch {
            print("❌ 녹음 시작 실패: \(error)")
            return nil
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordingTime = 0
        startTime = nil

        // 녹음 세션 해제 (재생을 위해)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ 녹음 세션 해제됨")
        } catch {
            print("⚠️ 녹음 세션 해제 실패: \(error)")
        }

        // 파일 유효성 검증
        if let url = audioURL {
            if FileManager.default.fileExists(atPath: url.path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int, size > 0 {
                print("✅ 녹음 파일 생성됨: \(url.lastPathComponent), \(size) bytes")
            } else {
                print("❌ 녹음 파일이 생성되지 않았거나 비어있음")
            }
        }

        // 연속 알림으로 30초마다 반복되므로 파일 확장 불필요
        onRecordingFinished?(audioURL)
    }

    func getAudioFilePath(fileName: String) -> URL {
        return getSoundsDirectory().appendingPathComponent(fileName)
    }

    func deleteAudioFile(fileName: String) {
        let fileURL = getSoundsDirectory().appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ 오디오 파일 삭제됨: \(fileName)")
            }
        } catch {
            print("❌ 오디오 파일 삭제 실패: \(error)")
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
