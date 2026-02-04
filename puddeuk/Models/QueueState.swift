import Foundation
import SwiftData

@Model
final class QueueState {
    var lastSyncTimestamp: Date
    var scheduledIdentifiers: [String]
    var queueVersion: Int

    init() {
        self.lastSyncTimestamp = Date()
        self.scheduledIdentifiers = []
        self.queueVersion = 0
    }
}
