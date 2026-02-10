import SwiftUI
import SwiftData

struct AlarmView: View {
    let context: AlarmContext
    let alarm: Alarm?
    let modelContext: ModelContext

    @State private var isDismissed = false

    private var displayTitle: String {
        context.title.isEmpty ? "알람" : context.title
    }

    private var isSnoozeAlarm: Bool {
        context.title == "스누즈 알람"
    }

    private var displayTime: String {
        if let alarm = alarm {
            return alarm.timeString
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: context.scheduledTime)
    }

    private var audioFileName: String? {
        context.audioFileName
    }

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "alarm.fill")
                    .font(.omyu(size: 80))
                    .foregroundColor(.teal)
                    .scaleEffect(isDismissed ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: !isDismissed)

                Text(displayTitle)
                    .font(.omyu(size: 36))
                    .foregroundColor(.white)

                Text(displayTime)
                    .font(.omyu(size: 72)).bold()
                    .foregroundColor(.white)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        let minutes = alarm?.snoozeInterval ?? 5
                        snoozeAlarm(minutes: minutes)
                    } label: {
                        let minutes = alarm?.snoozeInterval ?? 5
                        Text("\(minutes)분 후 다시 알림")
                            .font(.omyu(size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(16)
                    }

                    Button {
                        stopAlarm()
                    } label: {
                        Text("끄기")
                            .font(.omyu(size: 20))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // 오디오는 ForegroundAlarmStrategy에서 이미 재생 중
            // 진동만 시작
            AlarmNotificationService.shared.startVibration()
        }
        .onDisappear {
            // 뷰가 사라질 때 정리
            AlarmNotificationService.shared.stopVibration()
        }
    }

    private func stopAlarm() {
        isDismissed = true
        AlarmNotificationService.shared.stopVibration()
        AlarmManager.shared.stopAlarmAudio()

        if let alarm = alarm, alarm.repeatDays.isEmpty {
            alarm.isEnabled = false
            try? modelContext.save()
        }

        Task {
            await MainActor.run {
                AnalyticsManager.shared.logAlarmDismissed()
                LiveActivityManager.shared.endCurrentActivity()

                if !isSnoozeAlarm {
                    AlarmManager.shared.showMissionComplete()
                } else {
                    AlarmManager.shared.dismissAlarm()
                }
            }
        }
    }

    private func snoozeAlarm(minutes: Int) {
        isDismissed = true
        AlarmNotificationService.shared.stopVibration()
        AlarmManager.shared.stopAlarmAudio()

        Task {
            await MainActor.run {
                AnalyticsManager.shared.logAlarmSnoozed(minutes: minutes)
                LiveActivityManager.shared.endCurrentActivity()
                AlarmManager.shared.dismissAlarm()
            }

            do {
                try await AlarmNotificationManager.shared.scheduleSnooze(
                    minutes: minutes,
                    audioFileName: audioFileName
                )
            } catch {
                await MainActor.run {
                    AnalyticsManager.shared.logAlarmScheduleFailed(message: "Snooze: \(error.localizedDescription)")
                }
            }
        }
    }
}
