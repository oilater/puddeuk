import SwiftUI

struct AlarmRow: View {
    let alarm: Alarm
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    if !alarm.title.isEmpty {
                        Text(alarm.title)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack(spacing: 4) {
                        Text(alarm.repeatDays.isEmpty ? "반복 없음" : alarm.repeatDaysString)
                            .font(.caption)
                            .foregroundColor(alarm.repeatDays.isEmpty ? .gray : .pink)

                        if alarm.audioFileName != nil {
                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundColor(.pink)
                        }
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { newValue in
                        alarm.isEnabled = newValue
                        Task {
                            if newValue {
                                try? await AlarmNotificationManager.shared.scheduleAlarm(alarm)
                            } else {
                                await AlarmNotificationManager.shared.cancelAlarm(alarm)
                            }
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .pink))
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
