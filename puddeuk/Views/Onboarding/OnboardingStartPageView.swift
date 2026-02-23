import SwiftUI

struct OnboardingStartPageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("onboarding.start.title")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("onboarding.start.subtitle")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingStartPageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
