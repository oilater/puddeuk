import Foundation
import SwiftUI
import SwiftData
import Combine
import AlarmKit

@MainActor
final class AddAlarmViewModel: ObservableObject, Identifiable {
    let id = UUID()
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
    private let alarmManager = AlarmKit.AlarmManager.shared

    var isEditing: Bool {
        alarm != nil
    }

    var navigationTitle: String {
        isEditing ? "알람 편집" : "새 알람"
    }

    init(modelContext: ModelContext, alarm: Alarm? = nil) {
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
            await updateExistingAlarm(existingAlarm, hour: hour, minute: minute)
        } else {
            await createNewAlarm(hour: hour, minute: minute)
        }
    }

    func deleteAlarm() async {
        guard let alarm = alarm else { return }

        // AlarmKit 취소
        try? alarmManager.cancel(id: alarm.id)

        // 오디오 파일 삭제
        if let audioFileName = alarm.audioFileName {
            let audioRecorder = AudioRecorder()
            _ = audioRecorder.deleteAudioFile(fileName: audioFileName)
        }

        modelContext.delete(alarm)
    }

    func showDeleteAlert() {
        showingDeleteAlert = true
    }

    private func updateExistingAlarm(_ existingAlarm: Alarm, hour: Int, minute: Int) async {
        // 기존 알람 취소
        try? alarmManager.cancel(id: existingAlarm.id)

        var updateSuccess = false

        do {
            try modelContext.transaction {
                existingAlarm.title = self.title
                existingAlarm.hour = hour
                existingAlarm.minute = minute
                existingAlarm.repeatDays = Array(self.repeatDays)
                existingAlarm.snoozeInterval = self.snoozeInterval
                existingAlarm.audioFileName = self.audioFileName
            }
            updateSuccess = true
        } catch {
            errorMessage = "알람 업데이트에 실패했습니다."
            showingErrorAlert = true
        }

        if updateSuccess {
            do {
                try await scheduleAlarm(existingAlarm)
            } catch {
                errorMessage = "알람 예약에 실패했습니다."
                showingErrorAlert = true
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

            try await scheduleAlarm(newAlarm)
        } catch {
            errorMessage = "알람 저장에 실패했습니다."
            showingErrorAlert = true
        }
    }

    private func scheduleAlarm(_ alarm: Alarm) async throws {
        try await AlarmKitHelper.scheduleAlarm(alarm)
    }
}
