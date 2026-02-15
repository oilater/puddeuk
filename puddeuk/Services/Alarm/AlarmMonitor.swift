import Combine
import Foundation
import SwiftData
import AlarmKit
import AVFoundation
import OSLog

/// 포그라운드에서 알람 울림을 감지하고 소리를 재생하는 모니터
@MainActor
class AlarmMonitor: ObservableObject {
    @Published var alertingAlarmID: UUID?
    @Published var alertingAlarmTitle: String?

    private var monitorTask: Task<Void, Never>?
    private let alarmManager = AlarmKit.AlarmManager.shared
    private var audioPlayer: AVAudioPlayer?
    private var currentlyPlayingID: UUID?
    private let modelContext: ModelContext

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
                        }
                    } else {
                        stopAudio()
                        alertingAlarmID = nil
                        alertingAlarmTitle = nil
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
        stopAudio()
        alertingAlarmID = nil
        alertingAlarmTitle = nil
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingID = nil
    }

    private func fetchAlarmTitle(for alarmID: UUID) -> String {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.id == alarmID }
        )
        let alarm = try? modelContext.fetch(descriptor).first
        let title = alarm?.title ?? ""
        return title.isEmpty ? "알람" : title
    }

    private func playAlarmSound(for alarmID: UUID) {
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
        Logger.alarm.info("기본 시스템 알람 사운드 사용 (.default)")
    }
}
