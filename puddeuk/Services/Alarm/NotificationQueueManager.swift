//
//  NotificationQueueManager.swift
//  puddeuk
//
//  Created by Claude on 2026-02-04.
//

import Foundation
import SwiftData
import UserNotifications
import OSLog

/// Manages the sliding window of scheduled notifications to work within iOS's 64 notification limit
@MainActor
final class NotificationQueueManager {
    static let shared = NotificationQueueManager()

    // MARK: - Constants

    private enum Constants {
        static let maxIOSNotifications = 64
        static let quickRefillLimit = 10
    }

    // MARK: - Types

    struct ScheduledEvent: Comparable {
        let id: String
        let alarmId: UUID
        let fireDate: Date
        let chainIndex: Int
        let priority: Priority
        var isScheduled: Bool

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.fireDate < rhs.fireDate
        }

        enum Priority: Int, Comparable {
            case low = 0        // 7+ days: 2-chain
            case medium = 1     // 2-7 days: 4-chain
            case high = 2       // 24-48h: 8-chain
            case critical = 3   // <24h: 8-chain

            static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - State

    private var allPendingEvents: [ScheduledEvent] = []
    private var scheduledIdentifiers: Set<String> = []
    private var queueVersion: Int = 0

    private let logger = Logger(subsystem: "com.puddeuk.app", category: "NotificationQueue")

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public API

    /// Rebuilds the entire queue from all active alarms
    func rebuildQueue() async throws {
        guard let modelContext = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        logger.info("Rebuilding notification queue")

        // Fetch all enabled alarms
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.isEnabled }
        )
        let alarms = try modelContext.fetch(descriptor)

        var events: [ScheduledEvent] = []

        // Generate events for each alarm
        for alarm in alarms {
            guard let baseDate = alarm.nextFireDate else { continue }

            let priority = calculatePriority(for: baseDate)
            let chainCount = determineChainCount(priority: priority)
            let interval = AlarmChainCoordinator.shared.calculateChainInterval(
                for: alarm.audioFileName
            )

            for chainIndex in 0..<chainCount {
                let triggerDate = baseDate.addingTimeInterval(interval * Double(chainIndex))

                let event = ScheduledEvent(
                    id: "\(alarm.id.uuidString)-chain-\(chainIndex)",
                    alarmId: alarm.id,
                    fireDate: triggerDate,
                    chainIndex: chainIndex,
                    priority: priority,
                    isScheduled: false
                )
                events.append(event)
            }
        }

        // Sort by fire date
        allPendingEvents = events.sorted()

        logger.info("Queue rebuilt: \(events.count) total events")

        // Sync with iOS to mark already scheduled events
        await syncWithIOSScheduledNotifications()
    }

    /// Selects the next 64 events based on priority
    func selectNext64() -> [ScheduledEvent] {
        var selected: [ScheduledEvent] = []

        // Priority order: Critical -> High -> Medium -> Low
        for priority in [ScheduledEvent.Priority.critical, .high, .medium, .low] {
            let remaining = Constants.maxIOSNotifications - selected.count
            guard remaining > 0 else { break }

            let candidates = allPendingEvents
                .filter { !$0.isScheduled && $0.priority == priority }
                .prefix(remaining)

            selected.append(contentsOf: candidates)
        }

        logger.debug("Selected \(selected.count) events for scheduling")
        return selected
    }

    /// Schedules the next 64 events to iOS
    func scheduleNext64() async throws {
        let eventsToSchedule = selectNext64()

        logger.info("Scheduling \(eventsToSchedule.count) events to iOS")

        for event in eventsToSchedule {
            try await scheduleNotification(event)

            // Mark as scheduled
            if let index = allPendingEvents.firstIndex(where: { $0.id == event.id }) {
                allPendingEvents[index].isScheduled = true
            }
            scheduledIdentifiers.insert(event.id)
        }

        // Persist state
        await persistQueueState()

        let totalScheduled = self.scheduledIdentifiers.count
        logger.info("Scheduling complete: \(totalScheduled) total scheduled")
    }

    /// Checks available slots and refills if needed
    func checkAndRefill() async {
        logger.info("Checking for refill opportunities")

        // Sync with iOS first
        await syncWithIOSScheduledNotifications()

        let availableSlots = Constants.maxIOSNotifications - scheduledIdentifiers.count

        guard availableSlots > 0 else {
            logger.debug("No refill needed: all \(Constants.maxIOSNotifications) slots filled")
            return
        }

        logger.info("\(availableSlots) slots available, starting refill")

        // Rebuild queue (alarms may have changed)
        try? await rebuildQueue()

        // Schedule next batch
        try? await scheduleNext64()
    }

    /// Quick refill for notification service extension (30s time limit)
    func quickRefill() async {
        await syncWithIOSScheduledNotifications()

        let availableSlots = min(
            Constants.quickRefillLimit,
            Constants.maxIOSNotifications - scheduledIdentifiers.count
        )

        guard availableSlots > 0 else { return }

        let nextEvents = Array(selectNext64().prefix(availableSlots))

        logger.info("Quick refill: scheduling \(nextEvents.count) events")

        for event in nextEvents {
            try? await scheduleNotification(event)
            scheduledIdentifiers.insert(event.id)
        }
    }

    /// Full sync - used on app launch
    func performFullSync() async {
        logger.info("Performing full queue sync")

        await loadQueueState()
        await syncWithIOSScheduledNotifications()

        do {
            try await rebuildQueue()
            try await scheduleNext64()
            logger.info("Full sync complete")
        } catch {
            logger.error("Full sync failed: \(error.localizedDescription)")
        }
    }

    /// Removes all events for a specific alarm
    func removeAlarm(alarmId: UUID) async {
        let alarmIdString = alarmId.uuidString

        // Remove from queue
        allPendingEvents.removeAll { $0.alarmId == alarmId }

        // Remove from iOS
        let identifiersToRemove = self.scheduledIdentifiers.filter {
            $0.hasPrefix(alarmIdString)
        }

        if !identifiersToRemove.isEmpty {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: Array(identifiersToRemove))

            scheduledIdentifiers.subtract(identifiersToRemove)
            logger.info("Removed \(identifiersToRemove.count) events for alarm \(alarmIdString)")
        }

        await persistQueueState()
    }

    /// Increments queue version (triggers rebuild)
    func incrementQueueVersion() {
        queueVersion += 1
        let version = self.queueVersion
        logger.debug("Queue version: \(version)")
    }

    // MARK: - Priority Calculation

    private func calculatePriority(for date: Date) -> ScheduledEvent.Priority {
        let hoursUntil = date.timeIntervalSince(Date()) / 3600

        switch hoursUntil {
        case ..<24:
            return .critical  // <24h: 8-chain
        case 24..<48:
            return .high      // 24-48h: 8-chain
        case 48..<168:
            return .medium    // 2-7 days: 4-chain
        default:
            return .low       // 7+ days: 2-chain
        }
    }

    private func determineChainCount(priority: ScheduledEvent.Priority) -> Int {
        switch priority {
        case .critical, .high:
            return 8
        case .medium:
            return 4
        case .low:
            return 2
        }
    }

    // MARK: - iOS Sync

    private func syncWithIOSScheduledNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let iosScheduled = Set(requests.map { $0.identifier })

        scheduledIdentifiers = iosScheduled

        // Update event scheduled status
        for index in allPendingEvents.indices {
            allPendingEvents[index].isScheduled = iosScheduled.contains(allPendingEvents[index].id)
        }

        let pendingCount = self.scheduledIdentifiers.count
        logger.debug("iOS sync: \(pendingCount) notifications pending")
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(_ event: ScheduledEvent) async throws {
        guard let modelContext = modelContext else { return }

        // Fetch alarm - use descriptor without predicate to avoid macro issues
        let descriptor = FetchDescriptor<Alarm>()
        guard let alarms = try? modelContext.fetch(descriptor),
              let alarm = alarms.first(where: { $0.id == event.alarmId }) else {
            logger.error("Alarm not found: \(event.alarmId)")
            return
        }

        // Create notification content
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

        // User info
        content.userInfo = [
            "alarmId": event.alarmId.uuidString,
            "chainIndex": event.chainIndex,
            "isChainNotification": true
        ]

        // Schedule
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: event.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)

        logger.debug("Scheduled: \(event.id) at \(event.fireDate)")
    }

    // MARK: - State Persistence

    private func persistQueueState() async {
        guard let modelContext = modelContext else { return }

        // Delete old state
        let descriptor = FetchDescriptor<QueueState>()
        if let oldStates = try? modelContext.fetch(descriptor) {
            oldStates.forEach { modelContext.delete($0) }
        }

        // Save new state
        let state = QueueState()
        state.scheduledIdentifiers = Array(scheduledIdentifiers)
        state.lastSyncTimestamp = Date()
        state.queueVersion = queueVersion

        modelContext.insert(state)
        try? modelContext.save()

        logger.debug("Queue state persisted")
    }

    private func loadQueueState() async {
        guard let modelContext = modelContext else { return }

        let descriptor = FetchDescriptor<QueueState>()
        if let state = try? modelContext.fetch(descriptor).first {
            scheduledIdentifiers = Set(state.scheduledIdentifiers)
            queueVersion = state.queueVersion
            let scheduledCount = self.scheduledIdentifiers.count
            let version = self.queueVersion
            logger.info("Queue state loaded: \(scheduledCount) scheduled, version \(version)")
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Dumps queue state for debugging
    func dumpQueueState() {
        let totalEvents = self.allPendingEvents.count
        let scheduledCount = self.scheduledIdentifiers.count
        let version = self.queueVersion

        logger.info("=== Queue State Dump ===")
        logger.info("Total events: \(totalEvents)")
        logger.info("Scheduled: \(scheduledCount)")
        logger.info("Queue version: \(version)")

        let grouped = Dictionary(grouping: self.allPendingEvents) { $0.priority }
        for priority in [ScheduledEvent.Priority.critical, .high, .medium, .low] {
            let events = grouped[priority] ?? []
            let scheduledCount = events.filter { $0.isScheduled }.count
            let priorityName = String(describing: priority)
            logger.info("\(priorityName): \(events.count) total, \(scheduledCount) scheduled")
        }

        logger.info("=== End Queue State ===")
    }

    /// Returns queue statistics
    func getQueueStats() -> (total: Int, scheduled: Int, byPriority: [ScheduledEvent.Priority: Int]) {
        let byPriority = Dictionary(grouping: self.allPendingEvents) { $0.priority }
            .mapValues { $0.count }

        return (
            total: self.allPendingEvents.count,
            scheduled: self.scheduledIdentifiers.count,
            byPriority: byPriority
        )
    }
    #endif
}
