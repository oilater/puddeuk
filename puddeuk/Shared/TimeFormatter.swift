import Foundation

/// 알람까지 남은 시간을 사용자 친화적인 텍스트로 변환
struct TimeFormatter {

    /// 현재 시간부터 목표 시간까지 남은 시간을 계산하여 텍스트로 반환
    /// - Parameters:
    ///   - from: 시작 시간 (기본값: 현재 시간)
    ///   - to: 목표 시간 (알람 시간)
    /// - Returns: "2분 후에 알람이 울려요" 형식의 텍스트, 과거 시간이면 nil
    static func timeUntilAlarm(from: Date = Date(), to: Date) -> String? {
        let calendar = Calendar.current

        // 과거 시간이면 nil 반환 (초 단위 포함해서 체크)
        guard to > from else {
            return nil
        }

        // 초 단위 제거 (정확한 분 단위 계산을 위해)
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: from)
        let fireComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: to)

        guard let nowDate = calendar.date(from: nowComponents),
              let fireDate = calendar.date(from: fireComponents) else {
            return nil
        }

        // 초 단위 제거 후 같은 시간이면 "1분 안에"
        if nowDate == fireDate {
            return "1분 안에 알람이 울려요"
        }

        let components = calendar.dateComponents([.day, .hour, .minute], from: nowDate, to: fireDate)

        guard let days = components.day,
              let hours = components.hour,
              let minutes = components.minute else {
            return nil
        }

        // 포맷팅 로직
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

    /// 알람 객체를 받아서 남은 시간 텍스트 반환
    /// - Parameter alarm: 알람 객체
    /// - Returns: 남은 시간 텍스트, 계산 불가능하면 nil
    static func timeUntilAlarm(for alarm: Alarm) -> String? {
        guard alarm.isEnabled,
              let fireDate = alarm.nextFireDate else {
            return nil
        }

        let now = Date()
        print("🐛 [TimeFormatter] 현재 시간: \(now)")
        print("🐛 [TimeFormatter] 알람 시간: \(alarm.hour):\(alarm.minute)")
        print("🐛 [TimeFormatter] nextFireDate: \(fireDate)")
        print("🐛 [TimeFormatter] repeatDays: \(alarm.repeatDays)")

        return timeUntilAlarm(from: now, to: fireDate)
    }
}
