import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private let modelContext: ModelContext
    private let alarmManager: AlarmManager

    var hasAlarms: Bool {
        !alarms.isEmpty
    }

    var enabledAlarms: [Alarm] {
        alarms.filter { $0.isEnabled }
    }

    var disabledAlarms: [Alarm] {
        alarms.filter { !$0.isEnabled }
    }

    init(
        modelContext: ModelContext
    ) {
        self.modelContext = modelContext
        self.alarmManager = AlarmManager.shared
    }

    func loadAlarms() {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<Alarm>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )

        do {
            alarms = try modelContext.fetch(descriptor)
        } catch {
            showError(message: "알람 목록을 불러올 수 없습니다: \(error.localizedDescription)")
        }
    }

    func toggleAlarm(_ alarm: Alarm) async {
        alarm.isEnabled.toggle()

        do {
            try modelContext.save()

            let scheduler = AlarmSchedulerFactory.shared.createScheduler()
            if alarm.isEnabled {
                try await scheduler.scheduleAlarm(alarm)
            } else {
                try await scheduler.cancelAlarm(alarm)
            }
        } catch {
            alarm.isEnabled.toggle()
            showError(message: "알람 상태를 변경할 수 없습니다: \(error.localizedDescription)")
        }
    }

    func deleteAlarm(_ alarm: Alarm) async {
        do {
            let scheduler = AlarmSchedulerFactory.shared.createScheduler()
            try await scheduler.cancelAlarm(alarm)

            if let audioFileName = alarm.audioFileName {
                let audioRecorder = AudioRecorder()
                audioRecorder.deleteAudioFile(fileName: audioFileName)
            }

            modelContext.delete(alarm)
            try modelContext.save()
            alarms.removeAll { $0.id == alarm.id }

        } catch {
            showError(message: "알람을 삭제할 수 없습니다: \(error.localizedDescription)")
        }
    }

    func timeUntilNextAlarm() -> String? {
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

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
