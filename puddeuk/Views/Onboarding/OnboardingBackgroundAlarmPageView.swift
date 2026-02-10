import SwiftUI

struct OnboardingBackgroundAlarmPageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("앱을 종료해도\n알람이 잘 울려요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("iOS 26 버전 이하는 앱을 완전히 종료하면 기본 알람이 울려요")
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
    OnboardingBackgroundAlarmPageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
