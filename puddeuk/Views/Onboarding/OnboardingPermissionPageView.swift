import SwiftUI

struct OnboardingPermissionPageView: View {
    @State private var hasRequestedPermission = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("알람을\n놓치지 마세요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("정확한 시간에 알람을 받으려면\n알림 권한이 필요합니다")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if !hasRequestedPermission {
                Button {
                    Task {
                        await AlarmNotificationManager.shared.requestAuthorization()
                        hasRequestedPermission = true
                    }
                } label: {
                    Text("알림 권한 허용")
                        .font(.omyuHeadline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.teal)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.teal)
                    Text("권한 요청 완료")
                        .font(.omyuBody)
                        .foregroundColor(.teal)
                }
            }

            Spacer()

            Text("다음 페이지로 →")
                .font(.omyuSubheadline)
                .foregroundColor(.teal.opacity(0.7))
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    OnboardingPermissionPageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
