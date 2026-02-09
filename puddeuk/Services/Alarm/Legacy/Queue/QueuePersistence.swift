import Foundation
import SwiftData
import OSLog

@MainActor
final class QueuePersistence {
    private let logger = Logger(subsystem: "com.puddeuk.app", category: "QueuePersistence")

    nonisolated init() {}

    func save(scheduledIdentifiers: Set<String>, version: Int, to context: ModelContext) async {
        let descriptor = FetchDescriptor<QueueState>()
        if let oldStates = try? context.fetch(descriptor) {
            oldStates.forEach { context.delete($0) }
        }

        let state = QueueState()
        state.scheduledIdentifiers = Array(scheduledIdentifiers)
        state.lastSyncTimestamp = Date()
        state.queueVersion = version

        context.insert(state)
        try? context.save()

        logger.debug("Queue state persisted: version \(version)")
    }

    func load(from context: ModelContext) async -> (scheduledIdentifiers: Set<String>, version: Int)? {
        let descriptor = FetchDescriptor<QueueState>()

        guard let state = try? context.fetch(descriptor).first else {
            logger.debug("No saved queue state found")
            return nil
        }

        let identifiers = Set(state.scheduledIdentifiers)
        let version = state.queueVersion

        logger.info("Queue state loaded: \(identifiers.count) scheduled, version \(version)")
        return (identifiers, version)
    }
}
