import Foundation
import SwiftData
import UserNotifications
import OSLog

/// Handles actual scheduling of notifications to iOS
@MainActor
final class NotificationScheduler {
    private let logger = Logger(subsystem: "com.puddeuk.app", category: "NotificationScheduler")

    /// Schedule a single notification event to iOS
    func schedule(_ event: ScheduledEvent, alarm: Alarm) async throws {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = "알람 시간이에요. 퍼뜩 일어나세요! ☀️"
        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive

        // Add custom sound if available
        if let audioFileName = alarm.audioFileName {
            let soundName = UNNotificationSoundName(audioFileName)
            content.sound = UNNotificationSound(named: soundName)
        } else {
            content.sound = .defaultCritical
        }

        // User info for chain tracking
        content.userInfo = [
            "alarmId": event.alarmId.uuidString,
            "chainIndex": event.chainIndex,
            "isChainNotification": true
        ]

        // Create trigger from fire date
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: event.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)

        logger.debug("Scheduled: \(event.id) at \(event.fireDate)")
    }

    /// Fetch alarm from SwiftData
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

    /// Get all pending notification identifiers from iOS
    func getPendingIdentifiers() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map { $0.identifier })
    }

    /// Remove specific notification identifiers from iOS
    func remove(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)

        logger.info("Removed \(identifiers.count) notifications from iOS")
    }
}
