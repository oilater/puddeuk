import SwiftUI
import SwiftData
import UIKit
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour) private var alarms: [Alarm]
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    @ObservedObject private var alarmManager = AlarmManager.shared
    @ObservedObject private var presenter = AlarmUIPresenter.shared
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                if alarms.isEmpty {
                    EmptyAlarmView()
                } else {
                    AlarmListView(
                        alarms: sortedAlarms,
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
                AddAlarmView(viewModel: AddAlarmViewModel(modelContext: modelContext, alarm: nil))
            }
            .sheet(item: $selectedAlarm) { alarm in
                AddAlarmView(viewModel: AddAlarmViewModel(modelContext: modelContext, alarm: alarm))
            }
            .onAppear {
                setupAlarms()
            }
            .onReceive(timer) { _ in
                currentTime = Date()
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
                if let context = presenter.activeAlarmContext {
                    // Try to find the Alarm object from alarms array
                    let alarm = alarms.first { $0.id.uuidString == context.alarmId }
                    AlarmView(context: context, alarm: alarm)
                }
            }
            .fullScreenCover(isPresented: $alarmManager.showMissionCompleteView) {
                MissionCompleteView()
            }
        }
    }

    private var sortedAlarms: [Alarm] {
        // 시간순으로만 정렬 (활성화 상태 무관)
        alarms.sorted { alarm1, alarm2 in
            if alarm1.hour != alarm2.hour {
                return alarm1.hour < alarm2.hour
            }
            return alarm1.minute < alarm2.minute
        }
    }

    private var timeUntilNextAlarm: String? {
        let nextAlarm = alarms
            .filter { $0.isEnabled }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = alarm.nextFireDate else { return nil }
                return (alarm, date)
            }
            .min { $0.1 < $1.1 }

        guard let (_, date) = nextAlarm else {
            return nil
        }

        return TimeFormatter.timeUntilAlarm(from: Date(), to: date)
    }

    private func deleteAlarm(_ alarm: Alarm) {
        Task {
            await AlarmNotificationManager.shared.cancelAlarm(alarm)

            if let audioFileName = alarm.audioFileName {
                let audioRecorder = AudioRecorder()
                audioRecorder.deleteAudioFile(fileName: audioFileName)
            }

            modelContext.delete(alarm)
            try? modelContext.save()
        }
    }

    private func setupAlarms() {
        Task {
            for alarm in alarms where alarm.isEnabled {
                try? await AlarmNotificationManager.shared.scheduleAlarm(alarm)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
