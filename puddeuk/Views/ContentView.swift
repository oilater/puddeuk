import SwiftUI
import SwiftData
import UIKit
import Combine
import AlarmKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\Alarm.hour, order: .forward),
        SortDescriptor(\Alarm.minute, order: .forward)
    ]) private var alarms: [Alarm]
    @State private var activeViewModel: AddAlarmViewModel?
    @State private var currentTime = Date()
    @State private var timer: AnyCancellable?

    private let alarmManager = AlarmKit.AlarmManager.shared

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
                        activeViewModel = AddAlarmViewModel(modelContext: modelContext, alarm: alarm)
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
                        onAddTap: {
                            activeViewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
                        }
                    )
                }
            }
            .sheet(item: $activeViewModel) { vm in
                AddAlarmView(viewModel: vm)
            }
            .onAppear {
                setupAlarms()
                startTimer()
            }
            .onDisappear {
                timer?.cancel()
            }
            .task {
                for await _ in alarmManager.alarmUpdates {
                    currentTime = Date()
                }
            }
        }
    }

    private var timeUntilNextAlarm: String? {
        let nextDates = alarms
            .filter { $0.isEnabled }
            .compactMap { $0.nextFireDate }
        guard let closestDate = nextDates.min() else { return nil }
        return TimeFormatter.timeUntilAlarm(from: currentTime, to: closestDate)
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentTime = Date()
            }
    }

    private func deleteAlarm(_ alarm: Alarm) {
        Task {
            try? alarmManager.cancel(id: alarm.id)
            
            if let audioFileName = alarm.audioFileName {
                let audioRecorder = AudioRecorder()
                _ = audioRecorder.deleteAudioFile(fileName: audioFileName)
            }

            modelContext.delete(alarm)
            try? modelContext.save()
        }
    }

    private func setupAlarms() {
        Task { @MainActor in
            for alarm in alarms where alarm.isEnabled {
                try? await AlarmKitHelper.scheduleAlarm(alarm)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
