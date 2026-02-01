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
                        
                        VStack(spacing: 24) {
                            titleSection
                            repeatDaysSection
                            audioSection
                            
                            if isEditing {
                                deleteButton
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical)
                }
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
            .frame(maxWidth: .infinity)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("알람 이름")
                .font(.headline)
                .foregroundColor(.white)

            TextField("알람 이름을 입력해주세요", text: $title)
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
            Text("반복")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 8) {
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
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

            if audioRecorder.isRecording {
                recordingView
            } else if audioFileName != nil {
                recordedView
            } else {
                noRecordingView
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)

                Text("녹음 중... \(Int(audioRecorder.recordingTime))초")
                    .foregroundColor(.white)

                Spacer()
            }

            Button {
                audioRecorder.stopRecording()
                if let url = audioRecorder.audioURL {
                    audioFileName = url.lastPathComponent
                }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                    Text("녹음 중지")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.pink)
                Text("녹음 완료")
                    .foregroundColor(.white)
                Spacer()
                Button {
                    audioPlayer.stop()
                    audioFileName = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 12) {
                Button {
                    if audioPlayer.isPlaying {
                        audioPlayer.stop()
                    } else if let fileName = audioFileName {
                        _ = audioPlayer.playPreview(fileName: fileName)
                    }
                } label: {
                    HStack {
                        Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))
                        Text(audioPlayer.isPlaying ? "정지" : "미리듣기")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink.opacity(0.8))
                    .cornerRadius(12)
                }

                Button {
                    audioPlayer.stop()
                    audioFileName = nil
                    _ = audioRecorder.startRecording()
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                        Text("다시 녹음")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var noRecordingView: some View {
        VStack(spacing: 12) {
            Text("녹음된 소리가 없습니다")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                _ = audioRecorder.startRecording()
            } label: {
                HStack {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 24))
                    Text("녹음 시작")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink.opacity(0.8))
                .cornerRadius(12)
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
