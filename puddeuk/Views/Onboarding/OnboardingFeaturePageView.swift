import SwiftUI

struct OnboardingFeaturePageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("내 목소리로\n알람을 등록해요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("부모님이나 연인의 목소리로도\n알람을 설정할 수 있어요")
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
    OnboardingFeaturePageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
