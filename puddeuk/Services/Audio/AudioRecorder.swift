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
        do {
            _ = try FileManager.default.getSoundsDirectory()
            Logger.audio.info("Library/Sounds 폴더 확인됨")
        } catch {
            Logger.audio.error("Library/Sounds 폴더 생성 실패: \(error.localizedDescription)")
        }
    }

    func startRecording() -> URL? {
        setupAudioSession()

        guard let soundsPath = try? FileManager.default.getSoundsDirectory() else {
            Logger.audio.error("Sounds 디렉토리 접근 실패")
            return nil
        }
        let uniqueName = "alarm_\(UUID().uuidString.prefix(8)).caf"
        let audioFilename = soundsPath.appendingPathComponent(uniqueName)

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

            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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
        onRecordingFinished?(originalURL)
    }

    func getAudioFilePath(fileName: String) -> URL {
        guard let soundsDirectory = try? FileManager.default.getSoundsDirectory() else {
            return URL(fileURLWithPath: "")
        }
        return soundsDirectory.appendingPathComponent(fileName)
    }

    func deleteAudioFile(fileName: String) -> Bool {
        guard let soundsDirectory = try? FileManager.default.getSoundsDirectory() else {
            return false
        }
        let fileURL = soundsDirectory.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Task { @MainActor in
                Logger.audio.warning("파일이 존재하지 않음: \(fileName)")
            }
            return false
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            Task { @MainActor in
                Logger.audio.info("파일 삭제 성공: \(fileName)")
            }
            return true
        } catch {
            Task { @MainActor in
                Logger.audio.error("파일 삭제 실패: \(error.localizedDescription)")
            }
            return false
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.audio.warning("녹음이 정상적으로 완료되지 않음")
        }
    }
}
 
