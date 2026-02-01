import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct AddAlarmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var audioRecorder = AudioRecorder()
    @State private var title: String = "알람"
    @State private var selectedTime: Date = Date()
    @State private var repeatDays: Set<Int> = []
    @State private var audioFileName: String?
    @State private var showingDeleteAlert = false

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
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        timePickerSection
                        titleSection
                        repeatDaysSection
                        audioSection
                        if isEditing {
                            deleteButton
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
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
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveAlarm()
                    }
                    .foregroundColor(.pink)
                    .fontWeight(.semibold)
                }
            }
            .alert("알람 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteAlarm()
                }
            } message: {
                Text("이 알람을 삭제하시겠습니까?")
            }
        }
    }

    private var timePickerSection: some View {
        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .frame(height: 150)
    }


    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("알람 이름")
                .font(.headline)
                .foregroundColor(.white)

            TextField("알람 이름", text: $title)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }

    private var repeatDaysSection: some View {
        let dayNames = ["일", "월", "화", "수", "목", "금", "토"]

        return VStack(alignment: .leading, spacing: 12) {
            Text("반복 요일")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    Button {
                        if repeatDays.contains(dayIndex) {
                            repeatDays.remove(dayIndex)
                        } else {
                            repeatDays.insert(dayIndex)
                        }
                    } label: {
                        Text(dayNames[dayIndex])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(repeatDays.contains(dayIndex) ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(repeatDays.contains(dayIndex) ? Color.pink : Color.gray.opacity(0.3))
                            .cornerRadius(22)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("알람 소리")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 16) {
                audioStatusView
                recordButton
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    @ViewBuilder
    private var audioStatusView: some View {
        if audioRecorder.isRecording {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)

                Text("녹음 중... \(Int(audioRecorder.recordingTime))초")
                    .foregroundColor(.white)

                Spacer()
            }
        } else if audioFileName != nil {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.pink)

                Text("녹음 완료")
                    .foregroundColor(.white)

                Spacer()

                Button {
                    audioFileName = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        } else {
            Text("녹음된 소리가 없습니다")
                .foregroundColor(.gray)
        }
    }

    private var recordButton: some View {
        Button {
            if audioRecorder.isRecording {
                audioRecorder.stopRecording()
                if let url = audioRecorder.audioURL {
                    let fileName = "\(UUID().uuidString).m4a"
                    audioFileName = audioRecorder.copyAudioFile(from: url, to: fileName)
                }
            } else {
                _ = audioRecorder.startRecording()
            }
        } label: {
            HStack {
                Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 24))

                Text(audioRecorder.isRecording ? "녹음 중지" : "녹음 시작")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(audioRecorder.isRecording ? Color.red.opacity(0.8) : Color.pink.opacity(0.8))
            .cornerRadius(12)
        }
    }

    private var deleteButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("알람 삭제")
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
                let fileName = "\(UUID().uuidString).m4a"
                audioFileName = audioRecorder.copyAudioFile(from: url, to: fileName)
            }
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if let existingAlarm = alarm {
            AlarmNotificationManager.shared.cancelAlarm(existingAlarm)

            existingAlarm.title = title
            existingAlarm.hour = hour
            existingAlarm.minute = minute
            existingAlarm.repeatDays = Array(repeatDays)
            if let fileName = audioFileName {
                existingAlarm.audioFileName = fileName
            }

            AlarmNotificationManager.shared.scheduleAlarm(existingAlarm)
        } else {
            let newAlarm = Alarm(
                title: title,
                hour: hour,
                minute: minute,
                isEnabled: true,
                audioFileName: audioFileName,
                repeatDays: Array(repeatDays)
            )
            modelContext.insert(newAlarm)

            AlarmNotificationManager.shared.scheduleAlarm(newAlarm)
        }

        dismiss()
    }

    private func deleteAlarm() {
        if let alarm = alarm {
            AlarmNotificationManager.shared.cancelAlarm(alarm)
            modelContext.delete(alarm)
        }
        dismiss()
    }
}

#Preview {
    AddAlarmView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
