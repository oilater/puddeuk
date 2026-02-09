import Foundation
import SwiftData
import UserNotifications
import OSLog

@MainActor
final class NotificationScheduler {
    private let logger = Logger(subsystem: "com.puddeuk.app", category: "NotificationScheduler")

    nonisolated init() {}

    func schedule(_ event: ScheduledEvent, alarm: Alarm) async throws {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요! ☀️"
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive

        if let audioFileName = alarm.audioFileName {
            let soundName = UNNotificationSoundName(audioFileName)
            content.sound = UNNotificationSound(named: soundName)
        } else {
            content.sound = .defaultCritical
        }

        content.userInfo = [
            "alarmId": event.alarmId.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title,
            "chainIndex": event.chainIndex,
            "isChainNotification": true
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: event.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)

        logger.debug("Scheduled: \(event.id) at \(event.fireDate)")
    }

    func fetchAlarm(with id: UUID, from context: ModelContext) -> Alarm? {
        let descriptor = FetchDescriptor<Alarm>()
        guard let alarms = try? context.fetch(descriptor) else {
            logger.error("Failed to fetch alarms")
            return nil
        }

        guard let alarm = alarms.first(where: { $0.id == id }) else {
            logger.error("Alarm not found: \(id)")
            return nil
        }

        return alarm
    }

    func getPendingIdentifiers() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map { $0.identifier })
    }

    func remove(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)

        logger.info("Removed \(identifiers.count) notifications from iOS")
    }
}
