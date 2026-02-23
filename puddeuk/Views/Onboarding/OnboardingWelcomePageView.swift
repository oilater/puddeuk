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
                Text("onboarding.welcome.title")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("onboarding.welcome.subtitle")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingWelcomePageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
