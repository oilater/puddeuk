import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AddAlarmViewModel
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()

    init(viewModel: AddAlarmViewModel) {
        self.viewModel = viewModel
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
                            RepeatDaySelector(repeatDays: $viewModel.repeatDays)
                            snoozeSection
                            RecordingControlsView(
                                audioRecorder: audioRecorder,
                                audioPlayer: audioPlayer,
                                audioFileName: $viewModel.audioFileName
                            )

                            if viewModel.isEditing {
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
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("button.cancel") {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        }
                        dismiss()
                    }
                    .font(.omyuBody)
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button.save") {
                        // Stop recording and capture filename before saving
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                            if let url = audioRecorder.audioURL {
                                viewModel.audioFileName = url.lastPathComponent
                            }
                        }

                        Task {
                            await viewModel.saveAlarm()
                            dismiss()
                        }
                    }
                    .font(.omyuBody)
                    .foregroundColor(.teal)
                }
            }
            .alert("alarm.delete.confirm.title", isPresented: $viewModel.showingDeleteAlert) {
                Button("button.cancel", role: .cancel) { }
                Button("button.delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAlarm()
                        dismiss()
                    }
                }
            } message: {
                Text("alarm.delete.confirm.message")
                    .font(.omyuBody)
            }
            .alert("error.generic", isPresented: $viewModel.showingErrorAlert) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var timePickerSection: some View {
        DatePicker("", selection: $viewModel.selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .frame(height: 180)
            .frame(maxWidth: .infinity)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            TextField("alarm.title.placeholder", text: $viewModel.title)
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
                        Button("button.done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
        }
    }

    private var snoozeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("alarm.snooze.label")
                .font(.omyuHeadline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                SnoozeButton(title: String(localized: "alarm.snooze.disabled"), interval: nil, selectedInterval: $viewModel.snoozeInterval)
                SnoozeButton(title: String(localized: "alarm.snooze.5min"), interval: 5, selectedInterval: $viewModel.snoozeInterval)
                SnoozeButton(title: String(localized: "alarm.snooze.10min"), interval: 10, selectedInterval: $viewModel.snoozeInterval)
                SnoozeButton(title: String(localized: "alarm.snooze.15min"), interval: 15, selectedInterval: $viewModel.snoozeInterval)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var deleteButton: some View {
        Button {
            viewModel.showDeleteAlert()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("alarm.delete")
                    .font(.omyuBody)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }

}

struct SnoozeButton: View {
    let title: String
    let interval: Int?
    @Binding var selectedInterval: Int?

    var body: some View {
        Button {
            selectedInterval = interval
        } label: {
            Text(title)
                .font(.omyuBody)
                .foregroundColor(selectedInterval == interval ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedInterval == interval ? Color.teal : Color.gray.opacity(0.3))
                .cornerRadius(8)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Alarm.self, configurations: config)
    let context = container.mainContext

    return AddAlarmView(viewModel: AddAlarmViewModel(modelContext: context, alarm: nil))
}
