import Foundation
import SwiftData
import UserNotifications
import OSLog

@MainActor
final class NotificationQueueManager {
    static let shared = NotificationQueueManager()


    private let priorityStrategy: PriorityStrategy
    private let persistence: QueuePersistence
    private let scheduler: NotificationScheduler
    private let alarmScheduler = AlarmScheduler.shared


    private enum Constants {
        static let maxIOSNotifications = 60
        static let quickRefillLimit = 10
    }


    private var allPendingEvents: [ScheduledEvent] = []
    private var scheduledIdentifiers: Set<String> = []
    private var queueVersion: Int = 0

    private let logger = Logger(subsystem: "com.puddeuk.app", category: "NotificationQueue")

    private var modelContext: ModelContext?


    private init(
        priorityStrategy: PriorityStrategy,
        persistence: QueuePersistence,
        scheduler: NotificationScheduler
    ) {
        self.priorityStrategy = priorityStrategy
        self.persistence = persistence
        self.scheduler = scheduler
    }

    convenience init() {
        self.init(
            priorityStrategy: TimeBasedPriorityStrategy(),
            persistence: QueuePersistence(),
            scheduler: NotificationScheduler()
        )
    }

    static func create(
        priorityStrategy: PriorityStrategy,
        persistence: QueuePersistence,
        scheduler: NotificationScheduler
    ) -> NotificationQueueManager {
        return NotificationQueueManager(
            priorityStrategy: priorityStrategy,
            persistence: persistence,
            scheduler: scheduler
        )
    }


    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func rebuildQueue() async throws {
        guard let modelContext = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.isEnabled }
        )
        let alarms = try modelContext.fetch(descriptor)

        var events: [ScheduledEvent] = []

        for alarm in alarms {
            let alarmEvents = generateEvents(for: alarm)
            events.append(contentsOf: alarmEvents)
        }

        allPendingEvents = events.sorted()

        await syncWithIOSScheduledNotifications()
    }

    func selectNext60() -> [ScheduledEvent] {
        var selected: [ScheduledEvent] = []

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

    func scheduleNext60() async throws {
        guard let modelContext = modelContext else {
            logger.error("ModelContext not set")
            return
        }

        let eventsToSchedule = selectNext60()

        for event in eventsToSchedule {
            guard let alarm = scheduler.fetchAlarm(with: event.alarmId, from: modelContext) else {
                continue
            }

            try await scheduler.schedule(event, alarm: alarm)

            if let index = allPendingEvents.firstIndex(where: { $0.id == event.id }) {
                allPendingEvents[index].isScheduled = true
            }
            scheduledIdentifiers.insert(event.id)
        }

        await persistQueueState()
    }

    func checkAndRefill() async {

        await syncWithIOSScheduledNotifications()

        let availableSlots = Constants.maxIOSNotifications - scheduledIdentifiers.count

        guard availableSlots > 0 else {
            logger.debug("No refill needed: all \(Constants.maxIOSNotifications) slots filled")
            return
        }

        try? await rebuildQueue()

        try? await scheduleNext60()
    }

    func quickRefill() async {
        await syncWithIOSScheduledNotifications()

        let availableSlots = min(
            Constants.quickRefillLimit,
            Constants.maxIOSNotifications - scheduledIdentifiers.count
        )

        guard availableSlots > 0 else { return }

        let nextEvents = Array(selectNext60().prefix(availableSlots))

        guard let modelContext = modelContext else { return }

        for event in nextEvents {
            guard let alarm = scheduler.fetchAlarm(with: event.alarmId, from: modelContext) else {
                continue
            }

            try? await scheduler.schedule(event, alarm: alarm)
            scheduledIdentifiers.insert(event.id)
        }
    }

    func performFullSync() async {
        await loadQueueState()
        await syncWithIOSScheduledNotifications()

        do {
            try await rebuildQueue()
            try await scheduleNext60()
        } catch {
            logger.error("Full sync failed: \(error.localizedDescription)")
        }
    }

    func removeAlarm(alarmId: UUID) async {
        let alarmIdString = alarmId.uuidString

        allPendingEvents.removeAll { $0.alarmId == alarmId }

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


    private func generateEvents(for alarm: Alarm) -> [ScheduledEvent] {
        guard let baseDate = alarm.nextFireDate else { return [] }

        let priority = priorityStrategy.calculatePriority(for: baseDate, from: Date())
        let chainCount = priorityStrategy.determineChainCount(for: priority)
        let interval = alarmScheduler.calculateChainInterval(for: alarm.audioFileName)

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

    private func syncWithIOSScheduledNotifications() async {
        let iosScheduled = await scheduler.getPendingIdentifiers()

        scheduledIdentifiers = iosScheduled

        for index in allPendingEvents.indices {
            allPendingEvents[index].isScheduled = iosScheduled.contains(allPendingEvents[index].id)
        }

        logger.debug("iOS sync: \(self.scheduledIdentifiers.count) notifications pending")
    }

    private func persistQueueState() async {
        guard let modelContext = modelContext else { return }

        await persistence.save(
            scheduledIdentifiers: scheduledIdentifiers,
            version: queueVersion,
            to: modelContext
        )
    }

    private func loadQueueState() async {
        guard let modelContext = modelContext else { return }

        if let loaded = await persistence.load(from: modelContext) {
            scheduledIdentifiers = loaded.scheduledIdentifiers
            queueVersion = loaded.version
        }
    }


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
