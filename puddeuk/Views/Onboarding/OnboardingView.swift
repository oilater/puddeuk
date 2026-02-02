import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack {
                TabView(selection: $currentPage) {
                    OnboardingWelcomePageView()
                        .tag(0)

                    OnboardingBackgroundAlarmPageView()
                        .tag(1)

                    OnboardingFeaturePageView()
                        .tag(2)

                    OnboardingPermissionPageView()
                        .tag(3)

                    OnboardingStartPageView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
