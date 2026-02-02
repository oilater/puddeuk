import SwiftUI

struct OnboardingBackgroundAlarmPageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("앱을 종료해도\n시간에 맞춰 알람이 울려요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("무음모드는 꼭 풀어주세요!")
                    .font(.omyuBody)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                Text("설정 > 집중 모드 > 수면 에서 퍼뜩을 허용하면\n잘 때도 방해받지 않고 알람만 들을 수 있어요")
                    .font(.omyuBody)
                    .foregroundColor(.orange)
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
