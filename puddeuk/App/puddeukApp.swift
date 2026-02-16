import SwiftUI
import SwiftData
import OSLog
import FirebaseCore
import AlarmKit
import AVFoundation

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

        configureAudioSession()

        return true
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.interruptSpokenAudioAndMixWithOthers]
            )
            try audioSession.setActive(true)
            Logger.alarm.info("Audio Session 설정 완료")
        } catch {
            Logger.alarm.error("Audio Session 설정 실패: \(error.localizedDescription)")
        }
    }
}

@main
struct puddeukApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Alarm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var alarmMonitor = AlarmMonitor(
        modelContext: sharedModelContainer.mainContext
    )

    init() {
        setupDefaultFont()
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

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if hasCompletedOnboarding {
                        MainTabView()
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
            .fullScreenCover(isPresented: Binding(
                get: { alarmMonitor.alertingAlarmID != nil },
                set: { if !$0 { alarmMonitor.stopAlarm() } }
            )) {
                AlarmAlertView(
                    title: alarmMonitor.alertingAlarmTitle ?? "알람",
                    onStop: {
                        alarmMonitor.stopAlarm()
                    },
                    onSnooze: alarmMonitor.alertingAlarmHasSnooze ? {
                        alarmMonitor.snoozeAlarm()
                    } : nil
                )
            }
        }
        .modelContainer(Self.sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                alarmMonitor.startMonitoring()
            } else if newPhase == .background {
                alarmMonitor.stopMonitoring()
            }
        }
    }
}
