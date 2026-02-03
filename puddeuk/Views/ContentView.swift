import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour) private var alarms: [Alarm]
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    @ObservedObject private var alarmManager = AlarmManager.shared
    @State private var currentTime = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                if alarms.isEmpty {
                    EmptyAlarmView()
                } else {
                    AlarmListView(
                        alarms: alarms,
                        timeUntilNextAlarm: timeUntilNextAlarm
                    ) { alarm in
                        selectedAlarm = alarm
                    } onAlarmDelete: { alarm in
                        deleteAlarm(alarm)
                    }
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
                startTimer()
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

    private var nextAlarm: Alarm? {
        alarms
            .filter { $0.isEnabled }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let fireDate = alarm.nextFireDate else { return nil }
                return (alarm, fireDate)
            }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private var timeUntilNextAlarm: String? {
        guard let alarm = nextAlarm,
              let fireDate = alarm.nextFireDate else { return nil }

        let calendar = Calendar.current

        var nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentTime)
        nowComponents.second = 0

        var fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        fireComponents.second = 0

        guard let now = calendar.date(from: nowComponents),
              let fire = calendar.date(from: fireComponents) else { return nil }

        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: fire)

        guard let days = components.day,
              let hours = components.hour,
              let minutes = components.minute else { return nil }

        let totalDays = days

        if totalDays > 0 {
            return "\(totalDays)일 후에 알람이 울려요"
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)시간 \(minutes)분 후에 알람이 울려요"
            } else {
                return "\(hours)시간 후에 알람이 울려요"
            }
        } else if minutes > 0 {
            return "\(minutes)분 후에 알람이 울려요"
        } else {
            return "1분 안에 알람이 울려요"
        }
    }

    private func setupAlarms() {
        rescheduleActiveAlarms()
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
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
