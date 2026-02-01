//
//  puddeukApp.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct puddeukApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Alarm.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    AlarmNotificationManager.shared.requestAuthorization()
                    // 포그라운드에서도 알림 표시
                    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
