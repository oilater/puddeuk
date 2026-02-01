import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour) private var alarms: [Alarm]
    @State private var showingAddAlarm = false
    @State private var selectedAlarm: Alarm?
    @ObservedObject private var alarmManager = AlarmManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                if alarms.isEmpty {
                    EmptyAlarmView()
                } else {
                    AlarmListView(alarms: alarms) { alarm in
                        selectedAlarm = alarm
                    } onAlarmDelete: { alarm in
                        deleteAlarm(alarm)
                    }
                }
            }
            .navigationTitle("알람")
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
                AddAlarmView()
            }
            .sheet(item: $selectedAlarm) { alarm in
                AddAlarmView(alarm: alarm)
            }
            .onAppear {
                setupAlarms()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                AlarmNotificationManager.shared.checkPendingAlarm(modelContext: modelContext)
            }
            .onChange(of: alarmManager.showAlarmView) { _, show in
                // 알람 화면 표시 전 열린 sheet 닫기
                if show {
                    showingAddAlarm = false
                    selectedAlarm = nil
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
        }
    }

    private func setupAlarms() {
        rescheduleActiveAlarms()
    }

    private func rescheduleActiveAlarms() {
        for alarm in alarms where alarm.isEnabled {
            AlarmNotificationManager.shared.scheduleAlarm(alarm)
        }
    }

    private func deleteAlarm(_ alarm: Alarm) {
        AlarmNotificationManager.shared.cancelAlarm(alarm)
        // 연결된 오디오 파일도 삭제
        if let audioFileName = alarm.audioFileName {
            AudioRecorder().deleteAudioFile(fileName: audioFileName)
        }
        modelContext.delete(alarm)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Alarm.self, inMemory: true)
}
