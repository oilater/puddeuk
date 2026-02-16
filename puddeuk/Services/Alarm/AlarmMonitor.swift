import Combine
import Foundation
import MediaPlayer
import SwiftData
import AlarmKit
import AVFoundation
import AudioToolbox
import OSLog

@MainActor
class AlarmMonitor: ObservableObject {
    @Published var alertingAlarmID: UUID?
    @Published var alertingAlarmTitle: String?
    @Published var alertingAlarmHasSnooze: Bool = false

    private var monitorTask: Task<Void, Never>?
    private let alarmManager = AlarmKit.AlarmManager.shared
    private var audioPlayer: AVAudioPlayer?
    private var currentlyPlayingID: UUID?
    private let modelContext: ModelContext
    private var previousVolume: Float?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task {
            do {
                for try await alarms in alarmManager.alarmUpdates {
                    if let alertingAlarm = alarms.first(where: { $0.state == .alerting }) {
                        if currentlyPlayingID != alertingAlarm.id {
                            Logger.alarm.info("포그라운드 알람 감지: \(alertingAlarm.id)")
                            playAlarmSound(for: alertingAlarm.id)
                            currentlyPlayingID = alertingAlarm.id
                            alertingAlarmID = alertingAlarm.id
                            alertingAlarmTitle = fetchAlarmTitle(for: alertingAlarm.id)
                            alertingAlarmHasSnooze = fetchAlarmHasSnooze(for: alertingAlarm.id)
                        }
                    } else {
                        stopAudio()
                        alertingAlarmID = nil
                        alertingAlarmTitle = nil
                        alertingAlarmHasSnooze = false
                    }
                }
            } catch {
                Logger.alarm.error("알람 모니터링 실패: \(error.localizedDescription)")
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        stopAudio()
    }

    func stopAlarm() {
        guard let alarmID = alertingAlarmID else { return }
        do {
            try alarmManager.stop(id: alarmID)
            Logger.alarm.info("알람 정지: \(alarmID)")
        } catch {
            Logger.alarm.error("알람 정지 실패: \(error.localizedDescription)")
        }

        disableOneTimeAlarmIfNeeded(alarmID: alarmID)

        stopAudio()
        alertingAlarmID = nil
        alertingAlarmTitle = nil
        alertingAlarmHasSnooze = false
    }

    private func disableOneTimeAlarmIfNeeded(alarmID: UUID) {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmID }
        )
        guard let alarm = try? modelContext.fetch(descriptor).first else { return }

        if alarm.repeatDays.isEmpty {
            alarm.isEnabled = false
            try? modelContext.save()
        }
    }

    func snoozeAlarm() {
        guard let alarmID = alertingAlarmID else { return }
        do {
            try alarmManager.countdown(id: alarmID)
            Logger.alarm.info("알람 스누즈: \(alarmID)")
        } catch {
            Logger.alarm.error("알람 스누즈 실패: \(error.localizedDescription)")
        }
        stopAudio()
        alertingAlarmID = nil
        alertingAlarmTitle = nil
        alertingAlarmHasSnooze = false
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingID = nil
        restoreVolume()
        deactivateAudioSession()
    }

    private func fetchAlarmTitle(for alarmID: UUID) -> String {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmID }
        )
        let alarm = try? modelContext.fetch(descriptor).first
        let title = alarm?.title ?? ""
        return title.isEmpty ? "알람" : title
    }

    private func fetchAlarmHasSnooze(for alarmID: UUID) -> Bool {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmID }
        )
        let alarm = try? modelContext.fetch(descriptor).first
        return alarm?.snoozeInterval != nil && (alarm?.snoozeInterval ?? 0) > 0
    }

    private func setSystemVolumeToMax() {
        let session = AVAudioSession.sharedInstance()
        previousVolume = session.outputVolume

        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.001

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(volumeView)

            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    slider.value = 1.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        volumeView.removeFromSuperview()
                    }
                }
            }
        }
    }

    private func restoreVolume() {
        guard let volume = previousVolume else { return }

        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.001

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(volumeView)

            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    slider.value = volume
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        volumeView.removeFromSuperview()
                    }
                }
            }
        }
        previousVolume = nil
    }

    private func setupAlarmAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            Logger.alarm.error("알람 세션 설정 실패: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.alarm.error("오디오 세션 해제 실패: \(error.localizedDescription)")
        }
    }

    private func playAlarmSound(for alarmID: UUID) {
        setSystemVolumeToMax()
        setupAlarmAudioSession()

        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmID }
        )

        guard let alarm = try? modelContext.fetch(descriptor).first,
              let audioFileName = alarm.audioFileName else {
            Logger.alarm.warning("알람 또는 오디오 파일 정보 없음: \(alarmID)")
            playDefaultSound()
            return
        }

        guard let soundsDir = try? FileManager.default.getSoundsDirectory() else {
            Logger.alarm.error("Sounds 디렉토리 접근 실패")
            return
        }

        let audioURL = soundsDir.appendingPathComponent(audioFileName)

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            Logger.alarm.warning("오디오 파일 없음: \(audioFileName)")
            playDefaultSound()
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            Logger.alarm.info("포그라운드 알람 소리 재생: \(audioFileName)")
        } catch {
            Logger.alarm.error("알람 소리 재생 실패: \(error.localizedDescription)")
            playDefaultSound()
        }
    }

    private func playDefaultSound() {
        setSystemVolumeToMax()
        setupAlarmAudioSession()
        Logger.alarm.info("기본 알람 사운드 재생 (Reflection.caf)")

        guard let soundURL = Bundle.main.url(forResource: "Reflection", withExtension: "caf") else {
            Logger.alarm.error("Reflection.caf 파일을 찾을 수 없음")
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            Logger.alarm.error("기본 알람 소리 재생 실패: \(error.localizedDescription)")
        }
    }
}
