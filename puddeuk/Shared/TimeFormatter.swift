import Foundation

struct TimeFormatter {

    static func timeUntilAlarm(from: Date = Date(), to: Date) -> String? {
        let calendar = Calendar.current
        guard to > from else { return nil }

        let timeInterval = to.timeIntervalSince(from)
        let totalHours = Int(timeInterval / 3600)


        if totalHours < 24 {
            let components = calendar.dateComponents([.hour, .minute, .second], from: from, to: to)
            let hours = components.hour ?? 0
            let minutes = components.minute ?? 0
            let seconds = components.second ?? 0

            if hours == 0 && minutes == 0 && seconds > 0 {
                return String(localized: "time.until.alarm.under.minute")
            }

            var finalHours = hours
            var finalMinutes = (seconds > 0) ? (minutes + 1) : minutes

            if finalMinutes >= 60 {
                finalHours += 1
                finalMinutes = 0
            }

            if finalHours >= 24 {
                return String(localized: "time.until.alarm.one.day")
            }

            if finalHours > 0 {
                if finalMinutes > 0 {
                    return String(format: String(localized: "time.until.alarm.hours.minutes"), finalHours, finalMinutes)
                } else {
                    return String(format: String(localized: "time.until.alarm.hours"), finalHours)
                }
            } else {
                return String(format: String(localized: "time.until.alarm.minutes"), finalMinutes)
            }
        }

        let fromDate = calendar.startOfDay(for: from)
        let toDate = calendar.startOfDay(for: to)
        let dayComponents = calendar.dateComponents([.day], from: fromDate, to: toDate)
        let dayDifference = dayComponents.day ?? 0

        return String(format: String(localized: "time.until.alarm.days"), dayDifference)
    }

    static func timeUntilAlarm(for alarm: Alarm) -> String? {
        guard alarm.isEnabled,
              let fireDate = alarm.nextFireDate else {
            return nil
        }

        return timeUntilAlarm(from: Date(), to: fireDate)
    }
}
