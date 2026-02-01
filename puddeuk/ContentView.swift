//
//  ContentView.swift
//  puddeuk
//
//  Created by 성현 on 2/1/26.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour) private var alarms: [Alarm]
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    @ObservedObject private var alarmManager = AlarmManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()
                
                if alarms.isEmpty {
                    EmptyAlarmView()
                } else {
                    AlarmListView(alarms: alarms) { alarm in
                        selectedAlarm = alarm
                    }
                }
            }
            .navigationTitle("알람")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ToolbarButtons(
                        alarms: alarms,
                        onAddTap: { showingAddAlarm = true }
                    )
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView()
            }
            .sheet(item: $selectedAlarm) { alarm in
                AddAlarmView(alarm: alarm)
            }
            .onAppear {
                setupAlarms()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                AlarmNotificationManager.shared.checkPendingAlarm(modelContext: modelContext)
            }
            .fullScreenCover(isPresented: $alarmManager.showAlarmView) {
                if let alarm = alarmManager.activeAlarm {
                    AlarmView(alarm: alarm)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAlarms() {
        NotificationDelegate.shared.modelContext = modelContext
        rescheduleActiveAlarms()
    }
    
    private func rescheduleActiveAlarms() {
        for alarm in alarms where alarm.isEnabled {
            AlarmNotificationManager.shared.scheduleAlarm(alarm)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
