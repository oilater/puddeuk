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
        .navigationTitle("알림 설정")
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
                Text("알림 권한이 허용되었어요")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("알람이 정상적으로 울릴 거예요")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

            case .denied:
                Text("알림 권한이 거부되었어요")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("알람이 울리지 않아요\n설정에서 권한을 허용해주세요")
                    .font(.omyuBody)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

            case .notDetermined:
                Text("알림 권한이 필요해요")
                    .font(.omyu(size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("알람을 받으려면\n알림 권한을 허용해주세요")
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

            @unknown default:
                Text("알림 상태를 확인할 수 없어요")
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
                Text("설정으로 이동")
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
                Text(isLoading ? "요청 중..." : "알림 권한 요청하기")
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
                Text("설정 확인하기")
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
