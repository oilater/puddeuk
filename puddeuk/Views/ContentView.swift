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
                    } onAlarmDelete: { alarm in
                        deleteAlarm(alarm)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("기상 도움 많이 된다")
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
                Task {
                    await AlarmNotificationManager.shared.checkPendingAlarm(modelContext: modelContext)
                }
            }
            .onChange(of: alarmManager.showAlarmView) { _, show in
                if show {
                    showingAddAlarm = false
                    selectedAlarm = nil
                    alarmManager.showMissionCompleteView = false
                }
            }
            .fullScreenCover(isPresented: $alarmManager.showAlarmView) {
                if let alarm = alarmManager.activeAlarm {
                    AlarmView(alarm: alarm)
                } else if alarmManager.notificationTitle != nil {
                    AlarmView(
                        alarm: nil,
                        notificationTitle: alarmManager.notificationTitle,
                        notificationAudioFileName: alarmManager.notificationAudioFileName
                    )
                }
            }
            .fullScreenCover(isPresented: $alarmManager.showMissionCompleteView) {
                MissionCompleteView()
            }
        }
    }

    private func setupAlarms() {
        rescheduleActiveAlarms()
    }

    private func rescheduleActiveAlarms() {
        Task {
            for alarm in alarms where alarm.isEnabled {
                try? await AlarmNotificationManager.shared.scheduleAlarm(alarm)
            }
        }
    }

    private func deleteAlarm(_ alarm: Alarm) {
        let audioFileToDelete = alarm.audioFileName
        AnalyticsManager.shared.logAlarmDeleted()

        Task {
            await AlarmNotificationManager.shared.cancelAlarm(alarm)

            await MainActor.run {
                if let audioFileName = audioFileToDelete {
                    AudioRecorder().deleteAudioFile(fileName: audioFileName)
                }
                modelContext.delete(alarm)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
