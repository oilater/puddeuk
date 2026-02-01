import Foundation
import UserNotifications
import AVFoundation
import SwiftData
import UIKit
import Combine

final class AlarmNotificationService: NSObject, ObservableObject {

    static let shared = AlarmNotificationService()

    @Published var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var currentAlarmURL: URL?
    private var currentAudioFileName: String?

    // 백그라운드 알람 체크용
    private var alarmCheckTimer: Timer?
    private var pendingAlarms: [(hour: Int, minute: Int, audioFileName: String?, title: String)] = []

    private override init() {
        super.init()
        setupAudioSession()
        setupNotificationDelegate()
        observeAppState()
        createSilentAudioFile()
    }

    // MARK: - 대기 알람 등록
    func registerPendingAlarm(hour: Int, minute: Int, audioFileName: String?, title: String) {
        pendingAlarms.removeAll { $0.hour == hour && $0.minute == minute }
        pendingAlarms.append((hour, minute, audioFileName, title))
        print("📝 대기 알람: \(hour):\(String(format: "%02d", minute)) - \(title)")
    }

    func removePendingAlarm(hour: Int, minute: Int) {
        pendingAlarms.removeAll { $0.hour == hour && $0.minute == minute }
    }

    // MARK: - 오디오 세션
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback: 백그라운드 재생 허용
            // .duckOthers 제거: 다른 앱 볼륨 낮추지 않음
            // .defaultToSpeaker: 스피커로 출력 (최대 볼륨)
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("✅ 오디오 세션 설정 완료")
        } catch {
            print("❌ 오디오 세션 설정 실패:", error)
        }
    }

    /// 알람 재생 전 오디오 세션 최적화
    private func optimizeAudioSessionForAlarm() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 알람용 최적화: 볼륨 최대, 무음 모드 무시
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ 오디오 세션 최적화 실패:", error)
        }
    }

    // MARK: - 앱 상태 감시 (백그라운드 유지)
    private func observeAppState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        print("📱 백그라운드 전환")
        if !isAlarmPlaying {
            startSilentAudio()
        }
    }

    @objc private func appWillEnterForeground() {
        print("📱 포그라운드 전환")
        if !isAlarmPlaying {
            stopSilentAudio()
        }
    }

    // MARK: - 무음 오디오 (백그라운드 유지용)
    private func createSilentAudioFile() {
        let url = getSilentAudioURL()

        // 디렉토리 생성
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard !FileManager.default.fileExists(atPath: url.path) else {
            print("✅ 무음 파일 이미 존재")
            return
        }

        // 무음 오디오 데이터 직접 생성 (44100Hz, 1초, 모노, 16bit)
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)

        var audioData = Data()
        // 무음 샘플 (0값)
        for _ in 0..<numSamples {
            var sample: Int16 = 0
            audioData.append(Data(bytes: &sample, count: 2))
        }

        // CAF 헤더 생성은 복잡하므로 AVAudioFile 사용
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let audioFile = try AVAudioFile(forWriting: url, settings: settings)
            let format = audioFile.processingFormat
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
                print("❌ 버퍼 생성 실패")
                return
            }

            // 무음 버퍼 (기본값이 0이므로 그대로 사용)
            buffer.frameLength = AVAudioFrameCount(numSamples)
            try audioFile.write(from: buffer)
            print("✅ 무음 파일 생성됨: \(url.lastPathComponent)")
        } catch {
            print("❌ 무음 파일 생성 실패: \(error)")
        }
    }

    private func getSilentAudioURL() -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("Sounds").appendingPathComponent("_silent.caf")
    }

    private func startSilentAudio() {
        let url = getSilentAudioURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            createSilentAudioFile()
            return
        }

        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1
            // 무음 파일이므로 볼륨 1.0으로 설정 (알람 전환 시 볼륨 차이 방지)
            silentPlayer?.volume = 1.0
            silentPlayer?.play()
            print("🔇 무음 오디오 시작 (볼륨 1.0)")

            // 알람 시간 체크 시작
            startAlarmCheckTimer()
        } catch {
            print("❌ 무음 오디오 실패: \(error)")
        }
    }

    private func stopSilentAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = nil
    }

    // MARK: - 백그라운드 알람 시간 체크
    private func startAlarmCheckTimer() {
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAlarmTime()
        }
        // 백그라운드에서도 타이머가 작동하도록 common 모드에 추가
        if let timer = alarmCheckTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func checkAlarmTime() {
        guard !isAlarmPlaying else { return }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)

        // 정각 근처(0~2초)에만 체크
        guard second < 3 else { return }

        for alarm in pendingAlarms {
            if alarm.hour == hour && alarm.minute == minute {
                print("⏰ 백그라운드 알람: \(alarm.title)")
                triggerBackgroundAlarm(alarm)
                return
            }
        }
    }

    private func triggerBackgroundAlarm(_ alarm: (hour: Int, minute: Int, audioFileName: String?, title: String)) {
        print("🔔 triggerBackgroundAlarm 호출")

        // 타이머 중지
        alarmCheckTimer?.invalidate()
        alarmCheckTimer = nil

        // 알람 소리 시작
        if let fileName = alarm.audioFileName, !fileName.isEmpty {
            startAlarmWithFileName(fileName, keepSilentPlaying: true)
        } else {
            // 녹음된 소리 없음 - 무음 오디오만 중지
            silentPlayer?.stop()
            silentPlayer = nil
            isAlarmPlaying = true
        }

        // 알람 화면 표시
        DispatchQueue.main.async {
            AlarmManager.shared.showAlarmFromNotification(title: alarm.title, audioFileName: alarm.audioFileName)
        }
    }

    // MARK: - 알람 재생
    func startAlarmWithFileName(_ fileName: String, keepSilentPlaying: Bool = false) {
        print("🎵 알람 파일 재생 시도: \(fileName)")

        if !keepSilentPlaying {
            // 포그라운드에서 호출된 경우 무음 오디오 중지
            stopSilentAudio()
        }

        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
            .appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 파일 없음: \(fileName)")
            isAlarmPlaying = true
            if keepSilentPlaying {
                silentPlayer?.stop()
                silentPlayer = nil
            }
            return
        }

        // 파일 정보 확인
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int {
            print("📁 파일: \(fileName), \(size) bytes")
        }

        // 파일 확장자 확인 (m4a, caf, aac 지원)
        let ext = url.pathExtension.lowercased()
        if ext != "m4a" && ext != "caf" && ext != "aac" {
            print("⚠️ 지원되지 않는 형식: \(ext) - 알람을 삭제하고 다시 녹음해주세요")
        }

        currentAlarmURL = url
        currentAudioFileName = fileName
        playAlarm(stopSilentAfterStart: keepSilentPlaying)
    }

    private func playAlarm(stopSilentAfterStart: Bool = false) {
        guard let url = currentAlarmURL else { return }

        print("🎵 재생 시도: \(url.lastPathComponent)")

        // 먼저 알람 플레이어 생성 (오디오 세션 재설정 없이)
        do {
            alarmPlayer?.stop()
            alarmPlayer = nil

            // 오디오 세션 재설정 안함 - 이미 setupAudioSession에서 설정됨
            // 무음 오디오와 같은 세션 사용

            alarmPlayer = try AVAudioPlayer(contentsOf: url)
            alarmPlayer?.delegate = self
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.prepareToPlay()

            // 알람 플레이어 준비 완료 후 무음 오디오 중지
            if stopSilentAfterStart {
                silentPlayer?.stop()
                silentPlayer = nil
                print("🔇 무음 오디오 중지")
            }

            // 볼륨 최대 설정 (무음 오디오 중지 후)
            alarmPlayer?.volume = 1.0

            let success = alarmPlayer?.play() ?? false
            if success {
                isAlarmPlaying = true
                print("🎵 알람 재생 시작 ✅")
            } else {
                print("❌ 알람 재생 실패: play() returned false")
                isAlarmPlaying = true
            }
        } catch {
            print("❌ 알람 재생 실패: \(url.lastPathComponent)")
            print("   오류: \(error)")

            // 실패 시에도 무음 오디오 중지
            if stopSilentAfterStart {
                silentPlayer?.stop()
                silentPlayer = nil
            }

            isAlarmPlaying = true
        }
    }

    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        currentAlarmURL = nil
        currentAudioFileName = nil
        isAlarmPlaying = false
        print("🔇 알람 중지")
    }

    // MARK: - Notification Delegate
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AlarmNotificationService: UNUserNotificationCenterDelegate {

    /// 포그라운드에서 알림 수신
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"

        print("🔔 알람 (포그라운드): \(title)")

        if let fileName = audioFileName, !fileName.isEmpty {
            startAlarmWithFileName(fileName)
        } else {
            isAlarmPlaying = true
        }

        AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        completionHandler([])
    }

    /// 알림 탭
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let audioFileName = userInfo["audioFileName"] as? String
        let title = userInfo["title"] as? String ?? "알람"

        print("🔔 알림 탭: \(title)")

        await MainActor.run {
            if let fileName = audioFileName, !fileName.isEmpty {
                startAlarmWithFileName(fileName)
            } else {
                isAlarmPlaying = true
            }
            AlarmManager.shared.showAlarmFromNotification(title: title, audioFileName: audioFileName)
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AlarmNotificationService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isAlarmPlaying {
            print("⚠️ 알람 재시작")
            playAlarm()
        }
    }
}
