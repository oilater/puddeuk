import SwiftUI
import SwiftData
import UserNotifications
import OSLog

@main
struct puddeukApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Logger.alarm.info("앱 시작")
        _ = AlarmNotificationService.shared
        AlarmNotificationManager.shared.registerNotificationCategories()

        // 디버그: Library/Sounds 파일 목록 출력
        AlarmSoundService.shared.logAllSoundFiles()

        Task {
            await AlarmNotificationManager.shared.requestAuthorization()
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Alarm.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        Logger.alarm.debug("ScenePhase 변경: \(String(describing: oldPhase)) → \(String(describing: newPhase))")

        if newPhase == .active && oldPhase != .active {
            // 백그라운드/비활성 → 포그라운드 전환
            checkAndResumeAlarm()
        }
    }

    /// 포그라운드 전환 시 pending 알람 확인 및 재생
    private func checkAndResumeAlarm() {
        Task {
            let center = UNUserNotificationCenter.current()
            let delivered = await center.deliveredNotifications()

            // 전달된 알림 중 알람이 있는지 확인
            for notification in delivered {
                let userInfo = notification.request.content.userInfo

                guard let alarmId = userInfo["alarmId"] as? String,
                      let audioFileName = userInfo["audioFileName"] as? String,
                      !audioFileName.isEmpty else {
                    continue
                }

                let title = userInfo["title"] as? String ?? "알람"

                Logger.alarm.info("ScenePhase - 전달된 알람 발견: \(title)")

                // 이미 재생 중이 아니면 재생 시작
                await MainActor.run {
                    if !AlarmNotificationService.shared.isAlarmPlaying {
                        // 체인 알림 취소 (AVAudioPlayer로 대체)
                        AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

                        // AVAudioPlayer로 재생 시작
                        AlarmNotificationService.shared.startAlarmWithFileName(
                            audioFileName,
                            alarmId: alarmId
                        )

                        // Live Activity 시작
                        let formatter = DateFormatter()
                        formatter.dateFormat = "a h:mm"
                        formatter.locale = Locale(identifier: "ko_KR")
                        let timeString = formatter.string(from: Date())

                        LiveActivityManager.shared.startAlarmActivity(
                            alarmId: alarmId,
                            title: title,
                            scheduledTime: timeString,
                            audioFileName: audioFileName
                        )

                        // 알람 UI 표시
                        AlarmManager.shared.showAlarmFromNotification(
                            title: title,
                            audioFileName: audioFileName
                        )
                    }
                }

                // 처리한 알림 제거
                center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                break  // 첫 번째 알람만 처리
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "puddeuk" else { return }

        switch url.host {
        case "snooze":
            handleSnooze()
        case "dismiss":
            handleDismiss()
        default:
            break
        }
    }

    private func handleSnooze() {
        // 현재 재생 중인 오디오 파일명 저장 (stopAlarm 전에)
        let audioFileName = AlarmNotificationService.shared.getCurrentAudioFileName()

        AlarmNotificationService.shared.stopAlarm()
        Task { @MainActor in
            LiveActivityManager.shared.endCurrentActivity()
        }
        AlarmManager.shared.dismissAlarm()
        Task {
            // 같은 오디오 파일로 스누즈 예약
            try? await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: 5,
                audioFileName: audioFileName
            )
        }
    }

    private func handleDismiss() {
        AlarmNotificationService.shared.stopAlarm()
        Task { @MainActor in
            LiveActivityManager.shared.endCurrentActivity()
        }
        AlarmManager.shared.dismissAlarm()
    }
}
