import ActivityKit
import WidgetKit
import SwiftUI
import AlarmKit

@available(iOS 26.0, *)
private func modeDescription(_ mode: AlarmPresentationState.Mode) -> String {
    switch mode {
    case .countdown:
        return "카운트다운"
    case .paused:
        return "일시정지"
    @unknown default:
        return "알람"
    }
}

@available(iOS 26.0, *)
struct AlarmKitLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<PuddeukAlarmMetadata>.self) { context in
            // Lock Screen / 알림 센터 뷰
            HStack(spacing: 16) {
                Image(systemName: "alarm.fill")
                    .font(.title)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(modeDescription(context.state.mode))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text(context.attributes.presentation.alert.stopButton.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded 뷰
                DynamicIslandExpandedRegion(.leading) {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(modeDescription(context.state.mode))
                        .font(.caption)
                        .foregroundColor(.white)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Stop 버튼
                        Text(context.attributes.presentation.alert.stopButton.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundColor(.teal)
            } compactTrailing: {
                Text(modeDescription(context.state.mode))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
            } minimal: {
                Image(systemName: "alarm")
                    .foregroundColor(.teal)
            }
        }
    }
}

