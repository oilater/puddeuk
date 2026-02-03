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
    var snoozeInterval: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        hour: Int = 8,
        minute: Int = 0,
        isEnabled: Bool = true,
        audioFileName: String? = nil,
        repeatDays: [Int] = [],
        snoozeInterval: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.audioFileName = audioFileName
        self.repeatDays = repeatDays
        self.snoozeInterval = snoozeInterval
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

    var nextFireDate: Date? {
        guard isEnabled else { return nil }

        let calendar = Calendar.current
        let now = Date()

        if repeatDays.isEmpty {
            return nextOccurrence(from: now, calendar: calendar)
        }

        for daysAhead in 0..<8 {
            guard let candidateDate = candidateDate(daysAhead: daysAhead, from: now, calendar: calendar) else { continue }

            let weekday = calendar.component(.weekday, from: candidateDate) - 1

            if repeatDays.contains(weekday) && candidateDate > now {
                return candidateDate
            }
        }

        return nil
    }

    private func nextOccurrence(from date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var result = calendar.date(from: components) else { return nil }

        if result <= date {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        }

        return result
    }

    private func candidateDate(daysAhead: Int, from date: Date, calendar: Calendar) -> Date? {
        guard let futureDate = calendar.date(byAdding: .day, value: daysAhead, to: date) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }
}
