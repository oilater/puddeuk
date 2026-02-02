import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct AddAlarmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var title: String = ""
    @State private var selectedTime: Date = Date()
    @State private var repeatDays: Set<Int> = []
    @State private var audioFileName: String?
    @State private var showingDeleteAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    let alarm: Alarm?
    let isEditing: Bool

    init(alarm: Alarm? = nil) {
        self.alarm = alarm
        self.isEditing = alarm != nil

        if let alarm = alarm {
            _title = State(initialValue: alarm.title)
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            if let date = Calendar.current.date(from: components) {
                _selectedTime = State(initialValue: date)
            }
            _repeatDays = State(initialValue: Set(alarm.repeatDays))
            _audioFileName = State(initialValue: alarm.audioFileName)
        } else {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            if let date = Calendar.current.date(from: components) {
                _selectedTime = State(initialValue: date)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        timePickerSection

                        VStack(spacing: 24) {
                            titleSection
                            RepeatDaySelector(repeatDays: $repeatDays)
                            RecordingControlsView(
                                audioRecorder: audioRecorder,
                                audioPlayer: audioPlayer,
                                audioFileName: $audioFileName
                            )

                            if isEditing {
                                deleteButton
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(isEditing ? "알람 편집" : "새 알람")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                    .font(.omyuBody)
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveAlarm()
                    }
                    .font(.omyuBody)
                    .foregroundColor(.pink)
                }
            }
            .alert("알람 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteAlarm()
                }
            } message: {
                Text("이 알람을 삭제하시겠습니까?")
                    .font(.omyuBody)
            }
            .alert("오류", isPresented: $showingErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var timePickerSection: some View {
        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .scaleEffect(1.2)
            .frame(height: 180)
            .frame(maxWidth: .infinity)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            TextField("알람 이름을 입력해주세요", text: $title)
                .font(.omyuBody)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(.white)
                .padding(.top, 20)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("완료") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
        }
    }

    private var deleteButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("알람 삭제")
                    .font(.omyuBody)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func saveAlarm() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            if let url = audioRecorder.audioURL {
                audioFileName = url.lastPathComponent
            }
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let currentTitle = title
        let currentRepeatDays = Array(repeatDays)
        let currentAudioFileName = audioFileName

        if let existingAlarm = alarm {
            Task {
                await AlarmNotificationManager.shared.cancelAlarm(existingAlarm)

                var updateSuccess = false
                await MainActor.run {
                    do {
                        try modelContext.transaction {
                            existingAlarm.title = currentTitle
                            existingAlarm.hour = hour
                            existingAlarm.minute = minute
                            existingAlarm.repeatDays = currentRepeatDays
                            if let fileName = currentAudioFileName {
                                existingAlarm.audioFileName = fileName
                            }
                        }
                        updateSuccess = true
                    } catch {
                        errorMessage = "알람 업데이트에 실패했습니다."
                        showingErrorAlert = true
                    }
                }

                if updateSuccess {
                    do {
                        try await AlarmNotificationManager.shared.scheduleAlarm(existingAlarm)
                    } catch {
                        await MainActor.run {
                            errorMessage = "알람 예약에 실패했습니다. 다시 시도해주세요."
                            showingErrorAlert = true
                        }
                    }
                }
            }
        } else {
            let newAlarm = Alarm(
                title: currentTitle,
                hour: hour,
                minute: minute,
                isEnabled: true,
                audioFileName: currentAudioFileName,
                repeatDays: currentRepeatDays
            )
            modelContext.insert(newAlarm)

            do {
                try modelContext.save()

                Task {
                    do {
                        try await AlarmNotificationManager.shared.scheduleAlarm(newAlarm)
                    } catch {
                        await MainActor.run {
                            errorMessage = "알람 예약에 실패했습니다. 다시 시도해주세요."
                            showingErrorAlert = true
                        }
                    }
                }
            } catch {
                errorMessage = "알람 저장에 실패했습니다."
                showingErrorAlert = true
            }
        }

        dismiss()
    }

    private func deleteAlarm() {
        guard let alarm = alarm else {
            dismiss()
            return
        }

        let audioFileToDelete = alarm.audioFileName

        Task {
            await AlarmNotificationManager.shared.cancelAlarm(alarm)

            await MainActor.run {
                if let audioFileName = audioFileToDelete {
                    audioRecorder.deleteAudioFile(fileName: audioFileName)
                }
                modelContext.delete(alarm)
            }
        }

        dismiss()
    }
}

#Preview {
    AddAlarmView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
