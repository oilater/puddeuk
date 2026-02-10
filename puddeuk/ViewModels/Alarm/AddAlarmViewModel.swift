import Foundation
import SwiftUI
import SwiftData
import Combine
import OSLog

@MainActor
final class AddAlarmViewModel: ObservableObject {
    @Published var title: String
    @Published var selectedTime: Date
    @Published var repeatDays: Set<Int>
    @Published var audioFileName: String?
    @Published var snoozeInterval: Int?

    @Published var showingDeleteAlert: Bool = false
    @Published var showingErrorAlert: Bool = false
    @Published var errorMessage: String = ""

    private let modelContext: ModelContext
    private let alarm: Alarm?

    var isEditing: Bool {
        alarm != nil
    }

    var navigationTitle: String {
        isEditing ? "알람 편집" : "새 알람"
    }

    init(
        modelContext: ModelContext,
        alarm: Alarm? = nil
    ) {
        self.modelContext = modelContext
        self.alarm = alarm

        if let alarm = alarm {
            self.title = alarm.title

            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            self.selectedTime = Calendar.current.date(from: components) ?? Date()

            self.repeatDays = Set(alarm.repeatDays)
            self.audioFileName = alarm.audioFileName
            self.snoozeInterval = alarm.snoozeInterval
        } else {
            self.title = ""

            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            self.selectedTime = Calendar.current.date(from: components) ?? Date()

            self.repeatDays = []
            self.audioFileName = nil
            self.snoozeInterval = nil
        }
    }

    func saveAlarm() async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if let existingAlarm = alarm {
            await updateExistingAlarm(
                existingAlarm,
                hour: hour,
                minute: minute
            )
        } else {
            await createNewAlarm(
                hour: hour,
                minute: minute
            )
        }
    }

    func deleteAlarm() async {
        guard let alarm = alarm else { return }

        let audioFileToDelete = alarm.audioFileName

        await AlarmNotificationManager.shared.cancelAlarm(alarm)

        if let audioFileName = audioFileToDelete {
            let audioRecorder = AudioRecorder()
            audioRecorder.deleteAudioFile(fileName: audioFileName)
        }

        modelContext.delete(alarm)
    }

    func showDeleteAlert() {
        showingDeleteAlert = true
    }
    private func updateExistingAlarm(_ existingAlarm: Alarm, hour: Int, minute: Int) async {
        await AlarmNotificationManager.shared.cancelAlarm(existingAlarm)

        var updateSuccess = false

        do {
            try modelContext.transaction {
                existingAlarm.title = self.title
                existingAlarm.hour = hour
                existingAlarm.minute = minute
                existingAlarm.repeatDays = Array(self.repeatDays)
                existingAlarm.snoozeInterval = self.snoozeInterval
                if let fileName = self.audioFileName {
                    existingAlarm.audioFileName = fileName
                }
            }
            updateSuccess = true
        } catch {
            errorMessage = "알람 업데이트에 실패했습니다."
            showingErrorAlert = true
            AnalyticsManager.shared.logAlarmSaveFailed(message: error.localizedDescription)
        }

        if updateSuccess {
            AnalyticsManager.shared.logAlarmUpdated(hasCustomAudio: audioFileName != nil)

            do {
                try await AlarmNotificationManager.shared.scheduleAlarm(existingAlarm)
            } catch {
                errorMessage = "알람 예약에 실패했습니다. 다시 시도해주세요."
                showingErrorAlert = true
                AnalyticsManager.shared.logAlarmScheduleFailed(message: error.localizedDescription)
            }
        }
    }

    private func createNewAlarm(hour: Int, minute: Int) async {
        let newAlarm = Alarm(
            title: self.title,
            hour: hour,
            minute: minute,
            isEnabled: true,
            audioFileName: self.audioFileName,
            repeatDays: Array(self.repeatDays),
            snoozeInterval: self.snoozeInterval
        )

        modelContext.insert(newAlarm)

        do {
            try modelContext.save()
            AnalyticsManager.shared.logAlarmCreated(
                hasCustomAudio: audioFileName != nil,
                hasRepeat: !repeatDays.isEmpty,
                hasSnooze: snoozeInterval != nil
            )

            Task {
                do {
                    try await AlarmNotificationManager.shared.scheduleAlarm(newAlarm)
                } catch {
                    errorMessage = "알람 예약에 실패했습니다. 다시 시도해주세요."
                    showingErrorAlert = true
                    AnalyticsManager.shared.logAlarmScheduleFailed(message: error.localizedDescription)
                }
            }
        } catch {
            errorMessage = "알람 저장에 실패했습니다."
            showingErrorAlert = true
            AnalyticsManager.shared.logAlarmSaveFailed(message: error.localizedDescription)
        }
    }
}
