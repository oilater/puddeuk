import Foundation
import UserNotifications
import OSLog

final class BackgroundChainStrategy: AlarmPlaybackStrategy {
    private let gateway: NotificationGatewayProtocol
    private let soundFileManager: AlarmSoundFileManager
    private let chainCount: Int
    private let chainInterval: TimeInterval

    var requiresChainNotifications: Bool { true }

    init(
        gateway: NotificationGatewayProtocol = NotificationGateway.shared,
        soundFileManager: AlarmSoundFileManager = .shared,
        chainCount: Int = 15,
        chainInterval: TimeInterval = 11.0
    ) {
        self.gateway = gateway
        self.soundFileManager = soundFileManager
        self.chainCount = chainCount
        self.chainInterval = chainInterval
    }

    func activate(context: AlarmContext) async {
        let baseDate = Date()

        for i in 0..<chainCount {
            let fireDate = baseDate.addingTimeInterval(TimeInterval(i + 1) * chainInterval)

            let content = createChainContent(context: context, chainIndex: i)
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(context.alarmId)-chain-\(i)",
                content: content,
                trigger: trigger
            )

            do {
                try await gateway.addRequest(request)
            } catch {
                await MainActor.run {
                    Logger.alarm.error("❌ [BackgroundStrategy] 체인 \(i) 스케줄 실패: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            Logger.alarm.info("✅ [BackgroundStrategy] 체인 스케줄 완료: \(self.chainCount)개, 간격 \(self.chainInterval)초")
        }
    }

    func deactivate() async {
    }

    private func createChainContent(context: AlarmContext, chainIndex: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = context.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요!"
        content.sound = soundFileManager.notificationSound(for: context.audioFileName)
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": context.alarmId,
            "audioFileName": context.audioFileName ?? "",
            "title": context.title,
            "isChainNotification": true,
            "chainIndex": chainIndex
        ]
        return content
    }
}
