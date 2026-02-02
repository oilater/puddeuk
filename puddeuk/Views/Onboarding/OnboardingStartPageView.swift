import SwiftUI

struct OnboardingStartPageView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("이제\n시작해볼까요?")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("퍼뜩과 함께\n상쾌한 아침을 시작하세요")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("시작하기")
                    .font(.omyuHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.teal)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingStartPageView(hasCompletedOnboarding: .constant(false))
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
