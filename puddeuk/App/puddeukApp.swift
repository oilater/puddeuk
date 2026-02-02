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

        AlarmSoundService.shared.logAllSoundFiles()

        Task {
            await AlarmNotificationManager.shared.requestAuthorization()
        }

        // 앱 전체에 오뮤 다예쁨 폰트 적용
        setupDefaultFont()
    }

    private func setupDefaultFont() {
        if let customFont = UIFont(name: "omyu_pretty", size: 17) {
            // Navigation Bar
            UINavigationBar.appearance().titleTextAttributes = [.font: customFont.withSize(20)]
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: customFont.withSize(34)]

            // TabBar
            let tabBarFont = customFont.withSize(11)
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabBarFont], for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabBarFont], for: .selected)

            // TextField Placeholder
            UITextField.appearance().font = customFont
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
            MainTabView()
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
            checkAndResumeAlarm()
        }
    }

    private func checkAndResumeAlarm() {
        Task {
            let center = UNUserNotificationCenter.current()
            let delivered = await center.deliveredNotifications()

            for notification in delivered {
                let userInfo = notification.request.content.userInfo

                guard let alarmId = userInfo["alarmId"] as? String,
                      let audioFileName = userInfo["audioFileName"] as? String,
                      !audioFileName.isEmpty else {
                    continue
                }

                let title = userInfo["title"] as? String ?? "알람"

                Logger.alarm.info("ScenePhase - 전달된 알람 발견: \(title)")

                await MainActor.run {
                    if !AlarmNotificationService.shared.isAlarmPlaying {
                        AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

                        AlarmNotificationService.shared.startAlarmWithFileName(
                            audioFileName,
                            alarmId: alarmId
                        )

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

                        AlarmManager.shared.showAlarmFromNotification(
                            title: title,
                            audioFileName: audioFileName
                        )
                    }
                }

                center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                break
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
        let audioFileName = AlarmNotificationService.shared.getCurrentAudioFileName()

        AlarmNotificationService.shared.stopAlarm()
        Task { @MainActor in
            LiveActivityManager.shared.endCurrentActivity()
        }
        AlarmManager.shared.dismissAlarm()
        Task {
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
