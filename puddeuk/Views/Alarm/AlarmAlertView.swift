import SwiftUI

struct AlarmAlertView: View {
    let title: String
    let snoozeInterval: Int?
    let onStop: () -> Void
    let onSnooze: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    private var snoozeButtonText: String {
        guard let interval = snoozeInterval, interval > 0 else {
            return "5분 뒤 울림"
        }
        return "\(interval)분 뒤 울림"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.teal)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Text(title)
                    .font(.custom("omyu_pretty", size: 36))
                    .foregroundStyle(.white)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: onSnooze) {
                        Text(snoozeButtonText)
                            .font(.custom("omyu_pretty", size: 24))
                            .foregroundStyle(.black)
                            .frame(width: 200, height: 60)
                            .background(Color.teal)
                            .clipShape(Capsule())
                    }

                    Button(action: onStop) {
                        Text("끄기")
                            .font(.custom("omyu_pretty", size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 60)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            pulseScale = 1.15
        }
    }
}
