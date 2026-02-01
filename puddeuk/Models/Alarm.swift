import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var audioFileName: String?
    var repeatDays: [Int]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        hour: Int = 8,
        minute: Int = 0,
        isEnabled: Bool = true,
        audioFileName: String? = nil,
        repeatDays: [Int] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.audioFileName = audioFileName
        self.repeatDays = repeatDays
        self.createdAt = createdAt
    }

    var timeString: String {
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "오전" : "오후"
        return String(format: "%@ %d:%02d", period, hour12, minute)
    }

    var repeatDaysString: String {
        if repeatDays.isEmpty {
            return "반복 없음"
        }
        if repeatDays.count == 7 {
            return "매일"
        }
        let dayNames = ["일", "월", "화", "수", "목", "금", "토"]
        return repeatDays.sorted().map { dayNames[$0] }.joined(separator: " ")
    }
}
