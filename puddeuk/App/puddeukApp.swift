import SwiftUI
import SwiftData
import UserNotifications

@main
struct puddeukApp: App {

    init() {
        // AlarmNotificationService가 delegate 역할 수행 (연속 알림 포함)
        _ = AlarmNotificationService.shared

        AlarmNotificationManager.shared.requestAuthorization()
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
        }
        .modelContainer(sharedModelContainer)
    }
}
