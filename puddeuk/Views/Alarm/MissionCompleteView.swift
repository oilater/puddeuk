import SwiftUI

struct MissionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.omyu(size: 100))
                    .foregroundColor(.teal)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)

                VStack(spacing: 12) {
                    Text("좋은 하루 되세요!")
                        .font(.omyu(size: 36))
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1.0 : 0.0)

                    Text("자기 전에 생각 많이 날 거야")
                        .font(.omyu(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(isAnimating ? 1.0 : 0.0)
                }

                Spacer()
            }
        }
        .onAppear {
            startAnimation()
            scheduleAutoDismiss()
        }
    }

    private func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isAnimating = true
        }
    }

    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    MissionCompleteView()
}
