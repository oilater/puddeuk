import SwiftUI

struct OnboardingWelcomePageView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "alarm.fill")
                .font(.omyu(size: 100))
                .foregroundColor(.teal)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }

            VStack(spacing: 16) {
                Text("퍼뜩에 오신 것을\n환영해요!")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("내 목소리로 깨우는\n특별한 알람 앱")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text("왼쪽으로 스와이프하기 →")
                .font(.omyuSubheadline)
                .foregroundColor(.teal.opacity(0.7))
                .padding(.bottom, 60)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingWelcomePageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
