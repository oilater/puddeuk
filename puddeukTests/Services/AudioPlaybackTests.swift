import XCTest
import AVFoundation
@testable import puddeuk

/// 오디오 파일 재생 테스트
/// - 녹음 파일 존재 확인
/// - 오디오 파일 재생 가능 여부
/// - 파일 형식 검증
final class AudioPlaybackTests: XCTestCase {

    var testAudioFileName: String!

    override func setUp() {
        testAudioFileName = "test_\(UUID().uuidString).caf"
    }

    override func tearDown() {
        //  테스트 파일 정리
        deleteTestAudioFile(fileName: testAudioFileName)
    }

    // MARK: - Audio File Existence Tests

    func test_오디오파일_존재하지않음_false반환() {
        let nonExistentFile = "nonexistent_\(UUID().uuidString).caf"

        let exists = audioFileExists(fileName: nonExistentFile)

        XCTAssertFalse(exists, "존재하지 않는 파일은 false를 반환해야 함")
    }

    func test_생성된오디오파일_존재확인() throws {
        // 테스트용 더미 오디오 파일 생성
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path), "생성한 파일이 존재해야 함")

        // audioFileExists 함수로도 확인
        let exists = audioFileExists(fileName: testAudioFileName)
        XCTAssertTrue(exists, "생성한 오디오 파일이 존재해야 함")
    }

    // MARK: - Audio Playback Tests

    func test_오디오플레이어_파일재생가능() throws {
        // 테스트용 더미 오디오 파일 생성
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName)

        // AVAudioPlayer로 재생 가능한지 확인
        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            XCTAssertGreaterThan(player.duration, 0, "오디오 파일의 재생 시간이 0보다 커야 함")
            XCTAssertTrue(player.prepareToPlay(), "오디오 플레이어가 재생 준비되어야 함")
        } catch {
            XCTFail("오디오 파일 재생 준비 실패: \(error)")
        }
    }

    func test_오디오형식_CAF_Linear_PCM() throws {
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName)

        let audioFile = try AVAudioFile(forReading: audioURL)

        // 파일 형식 검증
        let format = audioFile.fileFormat

        XCTAssertEqual(format.commonFormat, .pcmFormatInt16, "오디오 형식은 16-bit Linear PCM이어야 함")
        XCTAssertEqual(format.sampleRate, 44100.0, "샘플레이트는 44.1kHz여야 함")
        XCTAssertEqual(format.channelCount, 1, "모노(1채널)여야 함")
    }

    // MARK: - Audio File Properties Tests

    func test_오디오파일_길이_정상범위() throws {
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName, duration: 2.0)

        let audioFile = try AVAudioFile(forReading: audioURL)
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate

        XCTAssertGreaterThan(duration, 1.9, "오디오 길이는 약 2초여야 함")
        XCTAssertLessThan(duration, 2.1, "오디오 길이는 약 2초여야 함")
    }

    func test_오디오진폭_정상범위() throws {
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName, amplitude: 0.5)

        let peak = try getPeakAmplitude(from: audioURL)

        XCTAssertGreaterThan(peak, 0.0, "피크 진폭은 0보다 커야 함")
        XCTAssertLessThanOrEqual(peak, 1.0, "피크 진폭은 1.0 이하여야 함")
    }

    // MARK: - File Management Tests

    func test_파일삭제_파일이제거됨() throws {
        let audioURL = try createDummyAudioFile(fileName: testAudioFileName)

        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path), "삭제 전 파일이 존재해야 함")

        deleteTestAudioFile(fileName: testAudioFileName)

        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path), "삭제 후 파일이 없어야 함")
    }

    func test_복수파일_독립적삭제() throws {
        let file1 = "test1_\(UUID().uuidString).caf"
        let file2 = "test2_\(UUID().uuidString).caf"

        let url1 = try createDummyAudioFile(fileName: file1)
        let url2 = try createDummyAudioFile(fileName: file2)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path))

        // file1만 삭제
        deleteTestAudioFile(fileName: file1)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url1.path), "file1이 삭제되어야 함")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path), "file2는 유지되어야 함")

        // 정리
        deleteTestAudioFile(fileName: file2)
    }

    // MARK: - Helper Methods

    private func audioFileExists(fileName: String) -> Bool {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")
        let audioURL = soundsPath.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: audioURL.path)
    }

    private func createDummyAudioFile(fileName: String, amplitude: Float = 0.5, duration: TimeInterval = 1.0) throws -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")

        // Sounds 디렉토리 생성
        try? FileManager.default.createDirectory(at: soundsPath, withIntermediateDirectories: true)

        let audioURL = soundsPath.appendingPathComponent(fileName)

        // CAF 형식으로 더미 오디오 생성
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let audioFile = try AVAudioFile(
            forWriting: audioURL,
            settings: settings,
            commonFormat: .pcmFormatInt16,
            interleaved: false
        )

        // 지정된 길이만큼 사인파 생성
        let sampleRate = 44100.0
        let frequency = 440.0 // A4 음
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "AudioTestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        buffer.frameLength = frameCount

        // 사인파 데이터 생성
        if let channelData = buffer.int16ChannelData {
            let maxAmplitude = Float(Int16.max) * amplitude
            for frame in 0..<Int(frameCount) {
                let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
                channelData[0][frame] = Int16(Float(value) * maxAmplitude)
            }
        }

        try audioFile.write(from: buffer)

        return audioURL
    }

    private func getPeakAmplitude(from url: URL) throws -> Float {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioTestError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer for reading"])
        }

        try audioFile.read(into: buffer)

        var peak: Float = 0.0

        if let channelData = buffer.int16ChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                let sample = Float(abs(channelData[0][frame])) / Float(Int16.max)
                peak = max(peak, sample)
            }
        }

        return peak
    }

    private func deleteTestAudioFile(fileName: String) {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")
        let audioURL = soundsPath.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: audioURL)
    }
}
