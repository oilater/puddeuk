import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch currentPage {
                    case 0: OnboardingWelcomePageView()
                    case 1: OnboardingBackgroundAlarmPageView()
                    case 2: OnboardingPermissionPageView()
                    case 3: OnboardingStartPageView()
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomButton
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
            }
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if currentPage == 2 {
            Button {
                Task {
                    await AlarmNotificationManager.shared.requestAuthorization()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentPage += 1
                    }
                }
            } label: {
                buttonLabel("알림 허용하기")
            }
        } else if currentPage == 3 {
            Button {
                AnalyticsManager.shared.logOnboardingCompleted()
                hasCompletedOnboarding = true
            } label: {
                buttonLabel("퍼뜩 시작하기")
            }
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentPage += 1
                }
            } label: {
                buttonLabel("다음")
            }
        }
    }

    private func buttonLabel(_ text: String) -> some View {
        Text(text)
            .font(.omyuHeadline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.teal)
            .cornerRadius(16)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
