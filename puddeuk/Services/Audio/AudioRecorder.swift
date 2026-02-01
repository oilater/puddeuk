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
        let audioFilename = soundsPath.appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
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
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingTime = Date().timeIntervalSince(startTime)
            }

            print("🎙️ 녹음 시작: \(audioFilename.lastPathComponent)")
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

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ 녹음 세션 해제됨")
        } catch {
            print("⚠️ 녹음 세션 해제 실패: \(error)")
        }

        guard let originalURL = audioURL else {
            onRecordingFinished?(nil)
            return
        }

        guard FileManager.default.fileExists(atPath: originalURL.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: originalURL.path),
              let size = attrs[.size] as? Int, size > 0 else {
            print("❌ 녹음 파일이 생성되지 않았거나 비어있음")
            onRecordingFinished?(nil)
            return
        }

        print("✅ 녹음 파일 생성됨: \(originalURL.lastPathComponent), \(size) bytes")

        createExtendedAudioFile(from: originalURL) { [weak self] extendedURL in
            self?.onRecordingFinished?(originalURL)
        }
    }

    private func createExtendedAudioFile(from originalURL: URL, completion: @escaping (URL?) -> Void) {
        let extendedFileName = originalURL.deletingPathExtension().lastPathComponent + "_extended.caf"
        let extendedURL = getSoundsDirectory().appendingPathComponent(extendedFileName)

        try? FileManager.default.removeItem(at: extendedURL)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let originalFile = try AVAudioFile(forReading: originalURL)
                let originalFormat = originalFile.processingFormat
                let originalLength = originalFile.length
                let sampleRate = originalFormat.sampleRate

                let originalDuration = Double(originalLength) / sampleRate
                print("📊 원본 오디오 길이: \(String(format: "%.1f", originalDuration))초")

                if originalDuration >= 30.0 {
                    print("✅ 이미 30초 이상이므로 확장 불필요")
                    DispatchQueue.main.async {
                        completion(originalURL)
                    }
                    return
                }

                guard let originalBuffer = AVAudioPCMBuffer(pcmFormat: originalFormat, frameCapacity: AVAudioFrameCount(originalLength)) else {
                    throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "버퍼 생성 실패"])
                }
                try originalFile.read(into: originalBuffer)

                let targetDuration: Double = 30.0
                let repeatCount = Int(ceil(targetDuration / originalDuration))
                let totalFrames = AVAudioFrameCount(originalLength) * AVAudioFrameCount(repeatCount)

                print("🔄 반복 횟수: \(repeatCount)회 → 총 \(String(format: "%.1f", Double(repeatCount) * originalDuration))초")

                guard let extendedBuffer = AVAudioPCMBuffer(pcmFormat: originalFormat, frameCapacity: totalFrames) else {
                    throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "확장 버퍼 생성 실패"])
                }

                let channelCount = Int(originalFormat.channelCount)
                for i in 0..<repeatCount {
                    let destOffset = Int(originalLength) * i
                    for channel in 0..<channelCount {
                        if let srcData = originalBuffer.floatChannelData?[channel],
                           let destData = extendedBuffer.floatChannelData?[channel] {
                            for frame in 0..<Int(originalLength) {
                                destData[destOffset + frame] = srcData[frame]
                            }
                        }
                    }
                }
                extendedBuffer.frameLength = totalFrames

                let outputSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: channelCount,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]

                let outputFile = try AVAudioFile(forWriting: extendedURL, settings: outputSettings)
                try outputFile.write(from: extendedBuffer)

                print("✅ 30초 확장 파일 생성: \(extendedFileName)")

                DispatchQueue.main.async {
                    completion(extendedURL)
                }
            } catch {
                print("❌ 확장 파일 생성 실패: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func getExtendedAudioFileName(for originalFileName: String) -> String {
        let baseName = (originalFileName as NSString).deletingPathExtension
        return baseName + "_extended.caf"
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

        let extendedFileName = getExtendedAudioFileName(for: fileName)
        let extendedURL = getSoundsDirectory().appendingPathComponent(extendedFileName)
        try? FileManager.default.removeItem(at: extendedURL)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("녹음이 성공적으로 완료되지 않았습니다")
        }
    }
}
