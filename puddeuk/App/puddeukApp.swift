import SwiftUI
import SwiftData
import UserNotifications
import OSLog
import FirebaseCore
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

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

        UNUserNotificationCenter.current().delegate = self
        Logger.alarm.info("📱 [AppDelegate] Notification Delegate 설정 완료")

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {

        Logger.alarm.info("🔔 [AppDelegate] willPresent 호출 - 알림 도착")

        guard isAlarmNotification(notification) else {
            Logger.alarm.info("ℹ️ [AppDelegate] 알람 아님, 기본 처리")
            return [.banner, .sound]
        }

        guard AlarmSchedulerFactory.shared.isLegacySystem else {
            Logger.alarm.info("⏭️ [AppDelegate] AlarmKit 사용 - willPresent 건너뜀")
            return []
        }

        Logger.alarm.info("⏰ [AppDelegate] Legacy 알람 감지 - 자동 재생 시작")

        startBackgroundTask()
        await setupAudioSession()
        await playAlarm(notification)
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {

        Logger.alarm.info("👆 [AppDelegate] didReceive 호출 - 사용자가 알림 탭")

        guard isAlarmNotification(response.notification) else {
            Logger.alarm.info("ℹ️ [AppDelegate] 알람 아님, 기본 처리")
            return
        }

        guard AlarmSchedulerFactory.shared.isLegacySystem else {
            Logger.alarm.info("⏭️ [AppDelegate] AlarmKit 사용 - didReceive 건너뜀")
            return
        }

        Logger.alarm.info("⏰ [AppDelegate] Legacy 알람 탭 - 재생 시작")
        await setupAudioSession()
        await playAlarm(response.notification)
    }

    private func isAlarmNotification(_ notification: UNNotification) -> Bool {
        return notification.request.content.userInfo["alarmId"] != nil
    }

    private func setupAudioSession() async {
        do {
            let session = AVAudioSession.sharedInstance()
            try await session.setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try await session.setActive(true)

            Logger.alarm.info("🔊 [AppDelegate] AVAudioSession 활성화 완료 (무음 모드 무시)")
        } catch {
            Logger.alarm.error("❌ [AppDelegate] AVAudioSession 설정 실패: \(error.localizedDescription)")
        }
    }

    private func playAlarm(_ notification: UNNotification) async {
        await MainActor.run {
            AlarmManager.shared.handleAlarmNotification(notification)
        }
    }

    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Logger.alarm.warning("⏱️ [AppDelegate] Background Task 시간 만료")
            self?.endBackgroundTask()
        }

        let timeRemaining = UIApplication.shared.backgroundTimeRemaining
        if timeRemaining != .infinity {
            Logger.alarm.info("⏱️ [AppDelegate] Background Task 시작 - 남은 시간: \(Int(timeRemaining))초")
        }
    }

    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid

        Logger.alarm.info("✅ [AppDelegate] Background Task 종료")
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
        guard AlarmSchedulerFactory.shared.isLegacySystem else {
            Logger.alarm.debug("⏭️ AlarmKit 사용 - checkAndResumeAlarm 건너뜀")
            return
        }

        Task {
            let center = UNUserNotificationCenter.current()
            let delivered = await center.deliveredNotifications()

            for notification in delivered {
                AlarmManager.shared.handleAlarmNotification(notification)
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
        Task {
            await MainActor.run {
                AlarmManager.shared.stopAlarmAudio()
                LiveActivityManager.shared.endCurrentActivity()
                AlarmManager.shared.dismissAlarm()
            }

            try? await AlarmNotificationManager.shared.scheduleSnooze(minutes: 5, audioFileName: nil)
        }
    }

    private func handleDismiss() {
        Task {
            await MainActor.run {
                AlarmManager.shared.stopAlarmAudio()
                LiveActivityManager.shared.endCurrentActivity()
                AlarmManager.shared.dismissAlarm()
            }
        }
    }
}
