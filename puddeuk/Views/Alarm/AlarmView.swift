import SwiftUI

struct AlarmView: View {
    let alarm: Alarm?
    var notificationTitle: String?
    var notificationAudioFileName: String?

    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var vibrationManager = VibrationManager()
    @State private var isDismissed = false

    private var displayTitle: String {
        if let alarm = alarm {
            return alarm.title.isEmpty ? "알람" : alarm.title
        }
        return notificationTitle ?? "알람"
    }

    private var displayTime: String {
        if let alarm = alarm {
            return alarm.timeString
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    private var audioFileName: String? {
        alarm?.audioFileName ?? notificationAudioFileName
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
                    if let alarm = alarm, let snoozeInterval = alarm.snoozeInterval {
                        Button {
                            snoozeAlarm(minutes: snoozeInterval)
                        } label: {
                            Text("\(snoozeInterval)분 후 다시 알림")
                                .font(.omyu(size: 18))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(16)
                        }
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
            startAlarm()
        }
        .onDisappear {
            stopAlarm()
        }
    }

    private func startAlarm() {
        guard !AlarmNotificationService.shared.isAlarmPlaying else {
            vibrationManager.start()
            return
        }

        if let fileName = audioFileName {
            audioPlayer.playAlarmSound(fileName: fileName)
        } else {
            audioPlayer.playDefaultSound()
        }
        vibrationManager.start()
    }

    private func stopAlarm() {
        isDismissed = true
        audioPlayer.stop()
        vibrationManager.stop()

        if let alarm = alarm {
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarm.id.uuidString)
        } else if let alarmId = AlarmNotificationService.shared.currentAlarmId {
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
        }

        AlarmNotificationService.shared.stopAlarm()

        Task { @MainActor in
            LiveActivityManager.shared.endCurrentActivity()
        }
        AlarmManager.shared.showMissionComplete()
    }

    private func snoozeAlarm(minutes: Int) {
        isDismissed = true
        audioPlayer.stop()
        vibrationManager.stop()

        if let alarm = alarm {
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarm.id.uuidString)
        } else if let alarmId = AlarmNotificationService.shared.currentAlarmId {
            AlarmNotificationManager.shared.cancelAlarmChain(alarmId: alarmId)
        }

        AlarmNotificationService.shared.stopAlarm()

        Task { @MainActor in
            LiveActivityManager.shared.endCurrentActivity()
        }
        AlarmManager.shared.dismissAlarm()

        Task {
            try? await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: minutes,
                audioFileName: audioFileName
            )
        }
    }
}
