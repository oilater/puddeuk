import Foundation

struct TimeFormatter {

    static func timeUntilAlarm(from: Date = Date(), to: Date) -> String? {
        let calendar = Calendar.current
        guard to > from else { return nil }

        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: from, to: to)

        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0

        if days == 0 && hours == 0 && minutes == 0 && seconds > 0 {
            return "1분 안에 알람이 울려요"
        }

        var finalMinutes = (seconds > 0) ? (minutes + 1) : minutes
        var finalHours = hours
        var finalDays = days

        if finalMinutes >= 60 {
            finalHours += 1
            finalMinutes -= 60
        }
        if finalHours >= 24 {
            finalDays += 1
            finalHours -= 24
        }

        if finalDays > 0 {
            return "\(finalDays)일 후에 알람이 울려요"
        } else if finalHours > 0 {
            if finalMinutes > 0 {
                return "\(finalHours)시간 \(finalMinutes)분 후에 알람이 울려요"
            } else {
                return "\(finalHours)시간 후에 알람이 울려요"
            }
        } else {
            return "\(finalMinutes)분 후에 알람이 울려요"
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
