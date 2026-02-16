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
                return "1분 안에 알람이 울려요"
            }

            let finalMinutes = (seconds > 0) ? (minutes + 1) : minutes

            if hours > 0 {
                if finalMinutes > 0 {
                    return "\(hours)시간 \(finalMinutes)분 후에 알람이 울려요"
                } else {
                    return "\(hours)시간 후에 알람이 울려요"
                }
            } else {
                return "\(finalMinutes)분 후에 알람이 울려요"
            }
        }

        let fromDate = calendar.startOfDay(for: from)
        let toDate = calendar.startOfDay(for: to)
        let dayComponents = calendar.dateComponents([.day], from: fromDate, to: toDate)
        let dayDifference = dayComponents.day ?? 0

        return "\(dayDifference)일 후에 알람이 울려요"
    }

    static func timeUntilAlarm(for alarm: Alarm) -> String? {
        guard alarm.isEnabled,
              let fireDate = alarm.nextFireDate else {
            return nil
        }

        return timeUntilAlarm(from: Date(), to: fireDate)
    }
}
