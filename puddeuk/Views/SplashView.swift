import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13)
                .ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(26.4)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
