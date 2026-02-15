import Foundation
import AlarmKit

public struct PuddeukAlarmMetadata: AlarmKit.AlarmMetadata {
    public let createdAt: Date
    public init() { self.createdAt = Date() }
}
