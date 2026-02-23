import SwiftUI
import AlarmKit

struct NotificationSettingsView: View {
    @State private var authorizationState: AlarmKit.AlarmManager.AuthorizationState = .notDetermined
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                statusIcon
                statusMessage
                actionButton

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .navigationTitle("notification.navigation.title")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            checkAlarmKitStatus()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch authorizationState {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.teal)
        case .denied:
            Image(systemName: "bell.slash.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.orange)
        case .notDetermined:
            Image(systemName: "bell.badge.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.gray)
        @unknown default:
            Image(systemName: "bell.fill")
                .font(.omyu(size: 80))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        VStack(spacing: 12) {
            switch authorizationState {
            case .authorized:
                Text("notification.authorized.title")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("notification.authorized.description")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

            case .denied:
                Text("notification.denied.title")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("notification.denied.description")
                    .font(.omyuBody)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

            case .notDetermined:
                Text("notification.notDetermined.title")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("notification.notDetermined.description")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

            @unknown default:
                Text("notification.status.unknown")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch authorizationState {
        case .denied:
            Button {
                openSettings()
            } label: {
                Text("notification.button.openSettings")
                    .font(.omyuHeadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.teal)
                    .cornerRadius(16)
            }

        case .notDetermined:
            Button {
                requestAlarmKitPermission()
            } label: {
                Text(isLoading ? "notification.button.requesting" : "notification.button.request")
                    .font(.omyuHeadline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.teal)
                    .cornerRadius(16)
            }
            .disabled(isLoading)

        case .authorized:
            Button {
                openSettings()
            } label: {
                Text("notification.button.checkSettings")
                    .font(.omyuHeadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(16)
            }

        @unknown default:
            EmptyView()
        }
    }

    private func checkAlarmKitStatus() {
        authorizationState = AlarmKit.AlarmManager.shared.authorizationState
    }

    private func requestAlarmKitPermission() {
        isLoading = true
        Task {
            _ = try? await AlarmKit.AlarmManager.shared.requestAuthorization()
            await MainActor.run {
                isLoading = false
            }
            checkAlarmKitStatus()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
