import SwiftUI
import Combine

struct AlarmCountdownView: View {
    let title: String
    let startTime: Date?
    let duration: Int?
    let onCancel: () -> Void

    @State private var remainingSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.teal)

                VStack(spacing: 12) {
                    Text("스누즈 중")
                        .font(.custom("omyu_pretty", size: 36))
                        .foregroundStyle(.white)

                    Text(title)
                        .font(.custom("omyu_pretty", size: 24))
                        .foregroundStyle(.gray)

                    Text(timeText)
                        .font(.custom("omyu_pretty", size: 48))
                        .foregroundStyle(.teal)
                        .monospacedDigit()
                }

                Spacer()

                Button(action: onCancel) {
                    Text("스누즈 취소")
                        .font(.custom("omyu_pretty", size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 60)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            updateRemainingTime()
        }
        .onReceive(timer) { _ in
            updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        guard let startTime = startTime, let duration = duration else {
            remainingSeconds = 0
            return
        }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        remainingSeconds = max(0, duration - elapsed)
    }
}
