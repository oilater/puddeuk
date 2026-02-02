import Foundation
import AVFoundation
import Combine
import OSLog

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
            Logger.audio.error("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }

    private func createSoundsDirectoryIfNeeded() {
        let soundsPath = getSoundsDirectory()
        if !FileManager.default.fileExists(atPath: soundsPath.path) {
            do {
                try FileManager.default.createDirectory(at: soundsPath, withIntermediateDirectories: true)
                Logger.audio.info("Library/Sounds 폴더 생성됨")
            } catch {
                Logger.audio.error("Library/Sounds 폴더 생성 실패: \(error.localizedDescription)")
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
        // 짧은 파일명: alarm_타임스탬프.caf (예: alarm_1738483200.caf)
        let timestamp = Int(Date().timeIntervalSince1970)
        let audioFilename = soundsPath.appendingPathComponent("alarm_\(timestamp).caf")

        // CAF 포맷 (Linear PCM) - iOS 알림 사운드용
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: AlarmConfiguration.audioSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: AlarmConfiguration.audioBitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
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

            Logger.audio.info("녹음 시작: \(audioFilename.lastPathComponent)")
            return audioFilename
        } catch {
            Logger.audio.error("녹음 시작 실패: \(error.localizedDescription)")
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
            // 확장 파일 생성 후 전체 파일 목록 출력
            AlarmSoundService.shared.logAllSoundFiles()
            self?.onRecordingFinished?(originalURL)
        }
    }

    private func createExtendedAudioFile(from originalURL: URL, completion: @escaping (URL?) -> Void) {
        // 짧은 확장 파일명: alarm_타임스탬프_ext.caf
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let extendedFileName = "\(baseName)_ext.caf"
        let extendedURL = getSoundsDirectory().appendingPathComponent(extendedFileName)

        print("🔧 [ExtendAudio] 시작")
        print("   원본: \(originalURL.lastPathComponent)")
        print("   대상: \(extendedFileName)")
        print("   저장 경로: \(extendedURL.path)")

        try? FileManager.default.removeItem(at: extendedURL)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let originalFile = try AVAudioFile(forReading: originalURL)
                let originalFormat = originalFile.processingFormat
                let originalLength = originalFile.length
                let sampleRate = originalFormat.sampleRate

                let originalDuration = Double(originalLength) / sampleRate
                print("🔧 [ExtendAudio] 원본 길이: \(String(format: "%.1f", originalDuration))초")
                print("   포맷: \(originalFormat)")

                if originalDuration >= AlarmConfiguration.maxNotificationSoundDuration {
                    print("🔧 [ExtendAudio] ⚠️ 이미 30초 이상 → 확장 건너뜀")
                    DispatchQueue.main.async {
                        completion(originalURL)
                    }
                    return
                }

                guard let originalBuffer = AVAudioPCMBuffer(pcmFormat: originalFormat, frameCapacity: AVAudioFrameCount(originalLength)) else {
                    throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "버퍼 생성 실패"])
                }
                try originalFile.read(into: originalBuffer)

                let targetDuration = AlarmConfiguration.maxNotificationSoundDuration
                let repeatCount = Int(ceil(targetDuration / originalDuration))
                let totalFrames = AVAudioFrameCount(originalLength) * AVAudioFrameCount(repeatCount)

                print("🔧 [ExtendAudio] 반복 횟수: \(repeatCount)회 → 총 \(String(format: "%.1f", Double(repeatCount) * originalDuration))초")

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

                // CAF 포맷 (Linear PCM) - iOS 노티피케이션 사운드에 최적화
                let outputSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: AlarmConfiguration.audioSampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: AlarmConfiguration.audioBitDepth,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]

                let outputFile = try AVAudioFile(forWriting: extendedURL, settings: outputSettings)
                try outputFile.write(from: extendedBuffer)

                // 파일 생성 확인
                if FileManager.default.fileExists(atPath: extendedURL.path) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: extendedURL.path),
                       let size = attrs[.size] as? Int {
                        print("🔧 [ExtendAudio] ✅ 파일 생성 완료: \(extendedFileName)")
                        print("   크기: \(size) bytes")
                        print("   경로: \(extendedURL.path)")
                    }
                } else {
                    print("🔧 [ExtendAudio] ❌ 파일이 생성되지 않음!")
                }

                DispatchQueue.main.async {
                    completion(extendedURL)
                }
            } catch {
                print("🔧 [ExtendAudio] ❌ 실패: \(error)")
                print("   원본 경로: \(originalURL.path)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    func getExtendedAudioFileName(for originalFileName: String) -> String {
        let baseName = (originalFileName as NSString).deletingPathExtension
        return baseName + "_ext.caf"
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
