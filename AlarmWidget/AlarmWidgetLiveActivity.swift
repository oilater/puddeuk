import ActivityKit
import WidgetKit
import SwiftUI

struct AlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            LockScreenAlarmView(context: context)
                .activityBackgroundTint(Color(red: 0.11, green: 0.11, blue: 0.13))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.pink)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatElapsedTime(context.state.elapsedSeconds))
                        .font(.title2.monospacedDigit())
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Link(destination: URL(string: "puddeuk://snooze")!) {
                            Text("5분 후")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(20)
                        }

                        Link(destination: URL(string: "puddeuk://dismiss")!) {
                            Text("끄기")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.pink)
                                .cornerRadius(20)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundColor(.pink)
            } compactTrailing: {
                Text(formatElapsedTime(context.state.elapsedSeconds))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundColor(.pink)
            }
        }
    }

    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct LockScreenAlarmView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.pink)
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Text(context.attributes.scheduledTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if context.state.isRinging {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("울리는 중")
                        .font(.caption)
                        .foregroundColor(.pink)
                    Text(formatElapsedTime(context.state.elapsedSeconds))
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
    }

    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview("Notification", as: .content, using: AlarmActivityAttributes.preview) {
    AlarmWidgetLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState.spiking
}

extension AlarmActivityAttributes {
    fileprivate static var preview: AlarmActivityAttributes {
        AlarmActivityAttributes(
            alarmId: "preview",
            title: "일어날 시간!",
            scheduledTime: "오전 7:00",
            audioFileName: nil
        )
    }
}

extension AlarmActivityAttributes.ContentState {
    fileprivate static var spiking: AlarmActivityAttributes.ContentState {
        AlarmActivityAttributes.ContentState(elapsedSeconds: 45, isRinging: true)
    }
}
