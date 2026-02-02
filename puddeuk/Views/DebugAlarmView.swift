import SwiftUI
import UserNotifications
import OSLog

struct DebugAlarmView: View {
    @State private var debugInfo: String = "탭하여 디버그 정보 로드..."
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button("디버그 정보 새로고침") {
                        Task {
                            await loadDebugInfo()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Text(debugInfo)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("알람 디버그")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadDebugInfo()
        }
    }

    private func loadDebugInfo() async {
        isLoading = true
        var info = ""

        let center = UNUserNotificationCenter.current()

        // 1. 알림 권한
        let settings = await center.notificationSettings()
        info += "🔐 알림 권한\n"
        info += "   상태: \(authStatusString(settings.authorizationStatus))\n"
        info += "   사운드: \(soundSettingString(settings.soundSetting))\n"
        info += "   알림: \(settings.alertSetting.rawValue)\n\n"

        // 2. 예약된 알림
        let pending = await center.pendingNotificationRequests()
        info += "⏰ 예약된 알림: \(pending.count)개\n"
        for (i, req) in pending.prefix(10).enumerated() {
            info += "   [\(i+1)] \(req.identifier)\n"
            info += "       \(req.content.title)\n"
            if let calTrigger = req.trigger as? UNCalendarNotificationTrigger {
                info += "       시간: \(formatDateComponents(calTrigger.dateComponents))\n"
            }
            if let intervalTrigger = req.trigger as? UNTimeIntervalNotificationTrigger {
                let mins = Int(intervalTrigger.timeInterval / 60)
                info += "       간격: \(mins)분 후\n"
            }

            // 사운드 정보 추출 (reflection 사용)
            let soundInfo = String(describing: req.content.sound)
            info += "       사운드: \(soundInfo)\n"
        }
        info += "\n"

        // 3. Library/Sounds 파일
        let fileManager = FileManager.default
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appendingPathComponent("Sounds")

        info += "📂 Library/Sounds\n"
        info += "   경로: \(soundsURL.path)\n"

        if fileManager.fileExists(atPath: soundsURL.path) {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: soundsURL.path)
                info += "   파일: \(files.count)개\n"
                for file in files.sorted() {
                    let filePath = soundsURL.appendingPathComponent(file).path
                    if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? Int {
                        let kb = size / 1024
                        info += "   - \(file) (\(kb) KB)\n"
                    }
                }
            } catch {
                info += "   ❌ 읽기 실패: \(error.localizedDescription)\n"
            }
        } else {
            info += "   ❌ 디렉토리 없음\n"
        }
        info += "\n"

        // 4. 전달된 알림
        let delivered = await center.deliveredNotifications()
        info += "📬 전달된 알림: \(delivered.count)개\n"
        for notif in delivered.prefix(5) {
            info += "   - \(notif.request.content.title)\n"
        }

        debugInfo = info
        isLoading = false

        Logger.alarm.info("디버그 정보 로드 완료")
    }

    private func authStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "미결정"
        case .denied: return "거부됨"
        case .authorized: return "허용됨 ✅"
        case .provisional: return "임시 허용"
        case .ephemeral: return "임시"
        @unknown default: return "알 수 없음"
        }
    }

    private func soundSettingString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "지원 안 함"
        case .disabled: return "비활성화됨 ⚠️"
        case .enabled: return "활성화됨 ✅"
        @unknown default: return "알 수 없음"
        }
    }

    private func formatDateComponents(_ components: DateComponents) -> String {
        if let hour = components.hour, let minute = components.minute {
            return String(format: "%02d:%02d", hour, minute)
        }
        return String(describing: components)
    }
}

#Preview {
    DebugAlarmView()
}
