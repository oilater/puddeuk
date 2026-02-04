import Foundation
import AVFoundation
import Combine
import OSLog

enum RecordingState: Equatable {
    case idle
    case recording
    case warning
    case limitReached
}

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var remainingTime: TimeInterval = AlarmConfiguration.maxRecordingDuration
    @Published var recordingState: RecordingState = .idle

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var hasTriggeredWarning = false

    var audioURL: URL?
    var onRecordingFinished: ((URL?) -> Void)?
    var onWarningReached: (() -> Void)?
    var onLimitReached: (() -> Void)?

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
        let audioFilename = soundsPath.appendingPathComponent("alarm.caf")

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
            recordingState = .recording
            hasTriggeredWarning = false
            remainingTime = AlarmConfiguration.maxRecordingDuration

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.startTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let maxDuration = AlarmConfiguration.maxRecordingDuration
                let warningThreshold = AlarmConfiguration.recordingWarningThreshold

                self.recordingTime = elapsed
                self.remainingTime = max(0, maxDuration - elapsed)

                if elapsed >= maxDuration {
                    self.recordingState = .limitReached
                    self.onLimitReached?()
                    self.stopRecording()
                } else if self.remainingTime <= warningThreshold && !self.hasTriggeredWarning {
                    self.recordingState = .warning
                    self.hasTriggeredWarning = true
                    self.onWarningReached?()
                } else if self.remainingTime > warningThreshold {
                    self.recordingState = .recording
                }
            }

            Logger.audio.info("녹음 시작: \(audioFilename.lastPathComponent)")
            return audioFilename
        } catch {
            Logger.audio.error("녹음 시작 실패: \(error.localizedDescription)")
            AnalyticsManager.shared.logRecordingStartFailed(message: error.localizedDescription)
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
        recordingState = .idle
        remainingTime = AlarmConfiguration.maxRecordingDuration
        hasTriggeredWarning = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.audio.warning("녹음 세션 해제 실패: \(error.localizedDescription)")
        }

        guard let originalURL = audioURL else {
            onRecordingFinished?(nil)
            return
        }

        guard FileManager.default.fileExists(atPath: originalURL.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: originalURL.path),
              let size = attrs[.size] as? Int, size > 0 else {
            Logger.audio.error("녹음 파일 생성 실패")
            onRecordingFinished?(nil)
            return
        }

        Logger.audio.info("녹음 완료: \(originalURL.lastPathComponent)")
        AlarmSoundService.shared.logAllSoundFiles()
        onRecordingFinished?(originalURL)
    }

    private func createExtendedAudioFile(from originalURL: URL, completion: @escaping (URL?) -> Void) {
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let extendedFileName = "\(baseName)_ext.caf"
        let extendedURL = getSoundsDirectory().appendingPathComponent(extendedFileName)

        try? FileManager.default.removeItem(at: extendedURL)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let originalFile = try AVAudioFile(forReading: originalURL)
                let originalFormat = originalFile.processingFormat
                let originalLength = originalFile.length
                let sampleRate = originalFormat.sampleRate

                let originalDuration = Double(originalLength) / sampleRate

                if originalDuration >= AlarmConfiguration.maxNotificationSoundDuration {
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
                    AVSampleRateKey: AlarmConfiguration.audioSampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: AlarmConfiguration.audioBitDepth,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ]

                let outputFile = try AVAudioFile(forWriting: extendedURL, settings: outputSettings)
                try outputFile.write(from: extendedBuffer)

                Task { @MainActor in
                    Logger.audio.info("30초 확장 파일 생성 완료: \(extendedURL.lastPathComponent)")
                }

                DispatchQueue.main.async {
                    completion(extendedURL)
                }
            } catch {
                Task { @MainActor in
                    Logger.audio.error("오디오 확장 실패: \(error.localizedDescription)")
                }
                AnalyticsManager.shared.logRecordingSaveFailed(message: error.localizedDescription)
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
            }
        } catch {
            Logger.audio.error("오디오 파일 삭제 실패: \(error.localizedDescription)")
        }

        let extendedFileName = getExtendedAudioFileName(for: fileName)
        let extendedURL = getSoundsDirectory().appendingPathComponent(extendedFileName)
        try? FileManager.default.removeItem(at: extendedURL)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.audio.warning("녹음이 정상적으로 완료되지 않음")
        }
    }
}
 
