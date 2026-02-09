import SwiftUI
import SwiftData
import UserNotifications
import OSLog
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        Task.detached(priority: .background) {
            FirebaseApp.configure()
            await MainActor.run {
                Logger.alarm.info("Firebase 초기화 완료")
            }
        }
        return true
    }
}

@main
struct puddeukApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    init() {
        Task { @MainActor in
            Logger.alarm.info("🚀 앱 시작")
            AlarmSystemInfo.shared.logSystemInfo()
        }

        setupDefaultFont()

        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                // ✨ Legacy 시스템일 때만 Audio Service 초기화
                if AlarmSchedulerFactory.shared.isLegacySystem {
                    Logger.alarm.info("🎵 Legacy Audio Service 초기화")
                    _ = AlarmNotificationService.shared
                } else {
                    Logger.alarm.info("⏭️ AlarmKit 사용 - Audio Service 건너뜀")
                }

                AlarmNotificationManager.shared.registerNotificationCategories()
            }

            #if DEBUG
            await MainActor.run {
                AlarmSoundFileManager.shared.logAllSoundFiles()
            }
            #endif

            await MainActor.run {
                Logger.alarm.info("✅ 백그라운드 초기화 완료")
            }
        }
    }

    private func setupDefaultFont() {
        if let customFont = UIFont(name: "omyu_pretty", size: 17) {
            UINavigationBar.appearance().titleTextAttributes = [.font: customFont.withSize(20)]
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: customFont.withSize(34)]

            let tabBarFont = customFont.withSize(11)
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabBarFont], for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabBarFont], for: .selected)

            UITextField.appearance().font = customFont
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Alarm.self,
            QueueState.self,
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
            ZStack {
                Group {
                    if hasCompletedOnboarding {
                        MainTabView()
                            .onOpenURL { url in
                                handleDeepLink(url)
                            }
                    } else {
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    }
                }
                .opacity(showSplash ? 0 : 1)
                .animation(.easeIn(duration: 0.5), value: showSplash)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }

                Task {
                    await initializeQueueManagerIfNeeded()
                }
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

            // ✨ Legacy 시스템일 때만 queue refill
            if AlarmSchedulerFactory.shared.isLegacySystem {
                Task {
                    Logger.alarm.debug("🔄 Legacy Queue refill 시작")
                    await NotificationQueueManager.shared.checkAndRefill()
                }
            } else {
                Logger.alarm.debug("⏭️ AlarmKit 사용 - Queue refill 건너뜀")
            }
        }
    }

    private func checkAndResumeAlarm() {
        // ✨ Legacy 시스템일 때만 실행
        guard AlarmSchedulerFactory.shared.isLegacySystem else {
            Logger.alarm.debug("⏭️ AlarmKit 사용 - checkAndResumeAlarm 건너뜀")
            return
        }

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

                await AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)

                await MainActor.run {
                    if !AlarmNotificationService.shared.isAlarmPlaying {
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

        Task {
            await AlarmNotificationService.shared.stopAlarm()

            await MainActor.run {
                LiveActivityManager.shared.endCurrentActivity()
                AlarmManager.shared.dismissAlarm()
            }

            try? await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: 5,
                audioFileName: audioFileName
            )
        }
    }

    private func handleDismiss() {
        Task {
            await AlarmNotificationService.shared.stopAlarm()

            await MainActor.run {
                LiveActivityManager.shared.endCurrentActivity()
                AlarmManager.shared.dismissAlarm()
            }
        }
    }

    private func initializeQueueManagerIfNeeded() async {
        guard AlarmSchedulerFactory.shared.isLegacySystem else {
            Logger.alarm.info("⏭️ AlarmKit 사용 - Queue Manager 초기화 건너뜀")
            return
        }

        Logger.alarm.info("🔄 Legacy Queue Manager 초기화 시작")

        await MainActor.run {
            NotificationQueueManager.shared.setModelContext(sharedModelContainer.mainContext)
        }

        await NotificationQueueManager.shared.performFullSync()
        Logger.alarm.info("✅ 알림 큐 매니저 초기화 완료")
    }
}
