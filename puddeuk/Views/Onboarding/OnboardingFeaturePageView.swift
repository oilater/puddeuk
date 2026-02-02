import SwiftUI

struct OnboardingFeaturePageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("목소리로\n알람을 만드세요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("사랑하는 사람의 목소리나\n좋아하는 노래로 알람을 설정하세요")
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
