import Foundation
import ActivityKit

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isRinging: Bool
    }

    var alarmId: String
    var title: String
    var scheduledTime: String
    var audioFileName: String?
}
