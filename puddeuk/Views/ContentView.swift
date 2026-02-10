import SwiftUI
import SwiftData
import UIKit
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AlarmListViewModel?
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    @ObservedObject private var alarmManager = AlarmManager.shared
    @State private var currentTime = Date()
    @State private var displayAlarms: [Alarm] = []

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                if let viewModel = viewModel {
                    if viewModel.alarms.isEmpty {
                        EmptyAlarmView()
                    } else {
                        AlarmListView(
                            alarms: displayAlarms,
                            timeUntilNextAlarm: viewModel.timeUntilNextAlarm()
                        ) { alarm in
                            selectedAlarm = alarm
                        } onAlarmDelete: { alarm in
                            Task {
                                await viewModel.deleteAlarm(alarm)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("기상 도움 많이 된다")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ToolbarButtons(
                        alarms: viewModel?.alarms ?? [],
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
            .task {
                if viewModel == nil {
                    viewModel = AlarmListViewModel(modelContext: modelContext)
                    viewModel?.loadAlarms()
                    updateDisplayAlarms()
                }
            }
            .onAppear {
                setupAlarms()
            }
            .onChange(of: viewModel?.alarms.count) { _, _ in
                updateDisplayAlarms()
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

    private func updateDisplayAlarms() {
        guard let viewModel = viewModel else { return }
        displayAlarms = viewModel.alarms.sorted { alarm1, alarm2 in
            let date1 = alarm1.nextFireDate
            let date2 = alarm2.nextFireDate

            switch (date1, date2) {
            case (nil, nil):
                return alarm1.hour < alarm2.hour
            case (nil, _):
                return false
            case (_, nil):
                return true
            case (let d1?, let d2?):
                return d1 < d2
            }
        }
    }

    private func setupAlarms() {
        rescheduleActiveAlarms()
    }

    private func rescheduleActiveAlarms() {
        guard let viewModel = viewModel else { return }
        Task {
            for alarm in viewModel.alarms where alarm.isEnabled {
                try? await AlarmNotificationManager.shared.scheduleAlarm(alarm)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
