import Foundation

struct TimeFormatter {

    static func timeUntilAlarm(from: Date = Date(), to: Date) -> String? {
        let calendar = Calendar.current

        guard to > from else {
            return nil
        }

        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: from)
        let fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: to)

        guard let nowDate = calendar.date(from: nowComponents),
              let fireDate = calendar.date(from: fireComponents) else {
            return nil
        }

        if nowDate == fireDate {
            return "1분 안에 알람이 울려요"
        }

        let components = calendar.dateComponents([.day, .hour, .minute], from: nowDate, to: fireDate)

        guard let days = components.day,
              let hours = components.hour,
              let minutes = components.minute else {
            return nil
        }

        if days > 0 {
            return "\(days)일 후에 알람이 울려요"
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)시간 \(minutes)분 후에 알람이 울려요"
            } else {
                return "\(hours)시간 후에 알람이 울려요"
            }
        } else if minutes > 0 {
            return "\(minutes)분 후에 알람이 울려요"
        } else {
            return "1분 안에 알람이 울려요"
        }
    }

    static func timeUntilAlarm(for alarm: Alarm) -> String? {
        guard alarm.isEnabled,
              let fireDate = alarm.nextFireDate else {
            return nil
        }

        return timeUntilAlarm(from: Date(), to: fireDate)
    }
}
