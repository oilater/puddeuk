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

                    OnboardingFeaturePageView()
                        .tag(1)

                    OnboardingPermissionPageView()
                        .tag(2)

                    OnboardingStartPageView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .tag(3)
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
