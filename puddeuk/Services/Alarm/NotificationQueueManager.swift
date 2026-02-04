import Foundation
import SwiftData
import UserNotifications
import OSLog

/// Manages the queue of notification events, ensuring iOS 60-notification limit is respected
/// while prioritizing imminent alarms with full chain coverage.
@MainActor
final class NotificationQueueManager {
    static let shared = NotificationQueueManager()

    // MARK: - Dependencies

    private let priorityStrategy: PriorityStrategy
    private let persistence: QueuePersistence
    private let scheduler: NotificationScheduler
    private let chainCoordinator: AlarmChainCoordinator

    // MARK: - Constants

    private enum Constants {
        static let maxIOSNotifications = 60
        static let quickRefillLimit = 10
    }

    // MARK: - State

    private var allPendingEvents: [ScheduledEvent] = []
    private var scheduledIdentifiers: Set<String> = []
    private var queueVersion: Int = 0

    private let logger = Logger(subsystem: "com.puddeuk.app", category: "NotificationQueue")

    private var modelContext: ModelContext?

    // MARK: - Initialization

    private init(
        priorityStrategy: PriorityStrategy,
        persistence: QueuePersistence,
        scheduler: NotificationScheduler,
        chainCoordinator: AlarmChainCoordinator
    ) {
        self.priorityStrategy = priorityStrategy
        self.persistence = persistence
        self.scheduler = scheduler
        self.chainCoordinator = chainCoordinator
    }

    convenience init() {
        self.init(
            priorityStrategy: TimeBasedPriorityStrategy(),
            persistence: QueuePersistence(),
            scheduler: NotificationScheduler(),
            chainCoordinator: AlarmChainCoordinator.shared
        )
    }

    // Testable initializer with dependency injection
    static func create(
        priorityStrategy: PriorityStrategy,
        persistence: QueuePersistence,
        scheduler: NotificationScheduler,
        chainCoordinator: AlarmChainCoordinator
    ) -> NotificationQueueManager {
        return NotificationQueueManager(
            priorityStrategy: priorityStrategy,
            persistence: persistence,
            scheduler: scheduler,
            chainCoordinator: chainCoordinator
        )
    }

    // MARK: - Public API

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Rebuild the entire queue from enabled alarms
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

        // Generate events for each alarm
        var events: [ScheduledEvent] = []

        for alarm in alarms {
            let alarmEvents = generateEvents(for: alarm)
            events.append(contentsOf: alarmEvents)
        }

        // Sort by fire date (earliest first)
        allPendingEvents = events.sorted()

        logger.info("Queue rebuilt: \(events.count) total events")

        // Sync with iOS to mark already scheduled events
        await syncWithIOSScheduledNotifications()
    }

    /// Select next batch of events to schedule, respecting iOS 60-notification limit
    func selectNext60() -> [ScheduledEvent] {
        var selected: [ScheduledEvent] = []

        // Priority order: Critical -> High -> Medium -> Low
        for priority in [ScheduledEventPriority.critical, .high, .medium, .low] {
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

    /// Schedule the next batch of events to iOS
    func scheduleNext60() async throws {
        guard let modelContext = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        let eventsToSchedule = selectNext60()

        logger.info("Scheduling \(eventsToSchedule.count) events to iOS")

        for event in eventsToSchedule {
            // Fetch alarm
            guard let alarm = scheduler.fetchAlarm(with: event.alarmId, from: modelContext) else {
                continue
            }

            // Schedule to iOS
            try await scheduler.schedule(event, alarm: alarm)

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

    /// Check for available slots and refill queue if needed
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
        try? await scheduleNext60()
    }

    /// Quick refill: schedule up to 10 events without full rebuild
    func quickRefill() async {
        await syncWithIOSScheduledNotifications()

        let availableSlots = min(
            Constants.quickRefillLimit,
            Constants.maxIOSNotifications - scheduledIdentifiers.count
        )

        guard availableSlots > 0 else { return }

        let nextEvents = Array(selectNext60().prefix(availableSlots))

        logger.info("Quick refill: scheduling \(nextEvents.count) events")

        guard let modelContext = modelContext else { return }

        for event in nextEvents {
            guard let alarm = scheduler.fetchAlarm(with: event.alarmId, from: modelContext) else {
                continue
            }

            try? await scheduler.schedule(event, alarm: alarm)
            scheduledIdentifiers.insert(event.id)
        }
    }

    /// Full sync: load state, sync with iOS, rebuild, and schedule
    func performFullSync() async {
        logger.info("Performing full queue sync")

        await loadQueueState()
        await syncWithIOSScheduledNotifications()

        do {
            try await rebuildQueue()
            try await scheduleNext60()
            logger.info("Full sync complete")
        } catch {
            logger.error("Full sync failed: \(error.localizedDescription)")
        }
    }

    /// Remove all notifications for a specific alarm
    func removeAlarm(alarmId: UUID) async {
        let alarmIdString = alarmId.uuidString

        // Remove from queue
        allPendingEvents.removeAll { $0.alarmId == alarmId }

        // Remove from iOS
        let identifiersToRemove = scheduledIdentifiers.filter {
            $0.hasPrefix(alarmIdString)
        }

        if !identifiersToRemove.isEmpty {
            scheduler.remove(identifiers: Array(identifiersToRemove))
            scheduledIdentifiers.subtract(identifiersToRemove)
            logger.info("Removed \(identifiersToRemove.count) events for alarm \(alarmIdString)")
        }

        await persistQueueState()
    }

    func incrementQueueVersion() {
        queueVersion += 1
        logger.debug("Queue version: \(self.queueVersion)")
    }

    // MARK: - Private Helpers

    /// Generate all chain events for a single alarm
    private func generateEvents(for alarm: Alarm) -> [ScheduledEvent] {
        guard let baseDate = alarm.nextFireDate else { return [] }

        let priority = priorityStrategy.calculatePriority(for: baseDate, from: Date())
        let chainCount = priorityStrategy.determineChainCount(for: priority)
        let interval = chainCoordinator.calculateChainInterval(for: alarm.audioFileName)

        var events: [ScheduledEvent] = []

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

        return events
    }

    /// Sync local state with iOS pending notifications
    private func syncWithIOSScheduledNotifications() async {
        let iosScheduled = await scheduler.getPendingIdentifiers()

        scheduledIdentifiers = iosScheduled

        // Update event scheduled status
        for index in allPendingEvents.indices {
            allPendingEvents[index].isScheduled = iosScheduled.contains(allPendingEvents[index].id)
        }

        logger.debug("iOS sync: \(self.scheduledIdentifiers.count) notifications pending")
    }

    /// Persist queue state to SwiftData
    private func persistQueueState() async {
        guard let modelContext = modelContext else { return }

        await persistence.save(
            scheduledIdentifiers: scheduledIdentifiers,
            version: queueVersion,
            to: modelContext
        )
    }

    /// Load queue state from SwiftData
    private func loadQueueState() async {
        guard let modelContext = modelContext else { return }

        if let loaded = await persistence.load(from: modelContext) {
            scheduledIdentifiers = loaded.scheduledIdentifiers
            queueVersion = loaded.version
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    func dumpQueueState() {
        logger.info("=== Queue State Dump ===")
        logger.info("Total events: \(self.allPendingEvents.count)")
        logger.info("Scheduled: \(self.scheduledIdentifiers.count)")
        logger.info("Queue version: \(self.queueVersion)")

        let grouped = Dictionary(grouping: self.allPendingEvents) { $0.priority }
        for priority in [ScheduledEventPriority.critical, .high, .medium, .low] {
            let events = grouped[priority] ?? []
            let scheduledCount = events.filter { $0.isScheduled }.count
            let priorityName = String(describing: priority)
            logger.info("\(priorityName): \(events.count) total, \(scheduledCount) scheduled")
        }

        logger.info("=== End Queue State ===")
    }

    func getQueueStats() -> (total: Int, scheduled: Int, byPriority: [ScheduledEventPriority: Int]) {
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
