import SwiftUI

struct AlarmView: View {
    /// Alarm 객체 (DB에서 온 경우)
    let alarm: Alarm?
    /// 알림에서 온 경우 제목
    var notificationTitle: String?
    /// 알림에서 온 경우 오디오 파일명
    var notificationAudioFileName: String?

    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var vibrationManager = VibrationManager()
    @State private var isDismissed = false

    /// 표시할 제목
    private var displayTitle: String {
        if let alarm = alarm {
            return alarm.title.isEmpty ? "알람" : alarm.title
        }
        return notificationTitle ?? "알람"
    }

    /// 표시할 시간
    private var displayTime: String {
        if let alarm = alarm {
            return alarm.timeString
        }
        // 알림에서 온 경우 현재 시간 표시
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }

    /// 오디오 파일명
    private var audioFileName: String? {
        alarm?.audioFileName ?? notificationAudioFileName
    }

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                    .scaleEffect(isDismissed ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: !isDismissed)

                Text(displayTitle)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text(displayTime)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    stopAlarm()
                } label: {
                    Text("끄기")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.pink)
                        .cornerRadius(16)
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
        // AlarmNotificationService가 이미 재생 중이면 스킵
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
        AlarmNotificationService.shared.stopAlarm()
        vibrationManager.stop()
        AlarmManager.shared.dismissAlarm()
    }
}
