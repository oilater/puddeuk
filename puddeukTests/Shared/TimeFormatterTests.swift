import XCTest
@testable import puddeuk

final class TimeFormatterTests: XCTestCase {


    func test_timeUntilAlarm_2minutesLater_returns2분후() {
        let now = createDate(hour: 10, minute: 15)
        let alarm = createDate(hour: 10, minute: 17)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "2분 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_1minuteLater_returns1분후() {
        let now = createDate(hour: 10, minute: 15)
        let alarm = createDate(hour: 10, minute: 16)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1분 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_30secondsLater_returns1분안에() {
        let now = createDate(hour: 10, minute: 15, second: 30)
        let alarm = createDate(hour: 10, minute: 15, second: 50)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1분 안에 알람이 울려요", "초 단위 차이는 1분 안에로 표시")
    }

    func test_timeUntilAlarm_59minutesLater_returns59분후() {
        let now = createDate(hour: 10, minute: 1)
        let alarm = createDate(hour: 11, minute: 0)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "59분 후에 알람이 울려요")
    }


    func test_timeUntilAlarm_1hourLater_returns1시간후() {
        let now = createDate(hour: 10, minute: 0)
        let alarm = createDate(hour: 11, minute: 0)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1시간 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_1hour30minutesLater_returns시간분() {
        let now = createDate(hour: 10, minute: 15)
        let alarm = createDate(hour: 11, minute: 45)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1시간 30분 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_3hoursLater_returns3시간후() {
        let now = createDate(hour: 9, minute: 0)
        let alarm = createDate(hour: 12, minute: 0)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "3시간 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_5hours45minutes_returns시간분() {
        let now = createDate(hour: 8, minute: 15)
        let alarm = createDate(hour: 14, minute: 0)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "5시간 45분 후에 알람이 울려요")
    }


    func test_timeUntilAlarm_crossMidnight_returns시간() {
        let now = createDate(hour: 23, minute: 0)
        let alarm = createDate(hour: 1, minute: 0, daysLater: 1)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "2시간 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_crossMidnight_returns분() {
        let now = createDate(hour: 23, minute: 50)
        let alarm = createDate(hour: 0, minute: 10, daysLater: 1)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "20분 후에 알람이 울려요")
    }


    func test_timeUntilAlarm_1dayLater_returns1일후() {
        let now = createDate(hour: 10, minute: 0)
        let alarm = createDate(hour: 10, minute: 0, daysLater: 1)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1일 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_2daysLater_returns2일후() {
        let now = createDate(hour: 9, minute: 0)
        let alarm = createDate(hour: 9, minute: 0, daysLater: 2)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "2일 후에 알람이 울려요")
    }

    func test_timeUntilAlarm_7daysLater_returns7일후() {
        let now = createDate(hour: 8, minute: 0)
        let alarm = createDate(hour: 8, minute: 0, daysLater: 7)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "7일 후에 알람이 울려요")
    }


    func test_timeUntilAlarm_pastTime_returnsNil() {
        let now = createDate(hour: 10, minute: 15)
        let alarm = createDate(hour: 10, minute: 10)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertNil(result, "과거 시간은 nil 반환")
    }

    func test_timeUntilAlarm_sameTime_returnsNil() {
        let now = createDate(hour: 10, minute: 15)
        let alarm = createDate(hour: 10, minute: 15)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertNil(result, "같은 시간은 nil 반환")
    }

    func test_timeUntilAlarm_yesterdayTime_returnsNil() {
        let now = createDate(hour: 10, minute: 0)
        let alarm = createDate(hour: 10, minute: 0, daysLater: -1)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertNil(result, "과거 날짜는 nil 반환")
    }


    func test_timeUntilAlarm_forAlarm_enabledAlarm_returnsText() {
        let alarm = Alarm(hour: 15, minute: 30, isEnabled: true)

        let result = TimeFormatter.timeUntilAlarm(for: alarm)

        XCTAssertNotNil(result, "활성화된 알람은 텍스트 반환")
    }

    func test_timeUntilAlarm_forAlarm_disabledAlarm_returnsNil() {
        let alarm = Alarm(hour: 15, minute: 30, isEnabled: false)

        let result = TimeFormatter.timeUntilAlarm(for: alarm)

        XCTAssertNil(result, "비활성화된 알람은 nil 반환")
    }


    func test_realWorld_morningAlarm() {
        let now = createDate(hour: 23, minute: 0)
        let alarm = createDate(hour: 8, minute: 0, daysLater: 1)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "9시간 후에 알람이 울려요", "밤에 다음날 아침 알람 설정")
    }

    func test_realWorld_napAlarm() {
        let now = createDate(hour: 14, minute: 0)
        let alarm = createDate(hour: 14, minute: 30)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "30분 후에 알람이 울려요")
    }

    func test_realWorld_weekendAlarm() {
        let now = createDate(hour: 22, minute: 0)
        let alarm = createDate(hour: 10, minute: 0, daysLater: 2)

        let result = TimeFormatter.timeUntilAlarm(from: now, to: alarm)

        XCTAssertEqual(result, "1일 후에 알람이 울려요")
    }


    private func createDate(hour: Int, minute: Int, second: Int = 0, daysLater: Int = 0) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = second

        guard var date = calendar.date(from: components) else {
            fatalError("Failed to create date")
        }

        if daysLater != 0 {
            date = calendar.date(byAdding: .day, value: daysLater, to: date) ?? date
        }

        return date
    }
}
