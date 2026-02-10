import SwiftUI

struct OnboardingPermissionPageView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)

            VStack(spacing: 16) {
                Text("알람 권한을\n허용해주세요")
                    .font(.omyu(size: 32))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("아침에 무조건 깨워드릴게요")
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
    OnboardingPermissionPageView()
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
}
