import XCTest
@testable import puddeuk

/// 알람 스케줄링 로직 테스트
/// - nextFireDate 계산
/// - 반복 알람 처리
/// - 과거 시간 처리
final class AlarmSchedulingTests: XCTestCase {
    
    // MARK: - One-time Alarm Tests

    func test_nextFireDate_미래시간_반복없음_다음발화시간계산() {
        let calendar = Calendar.current
        let now = Date()

        // 1시간 후 알람 설정
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now)!
        let components = calendar.dateComponents([.hour, .minute], from: oneHourLater)

        let alarm = Alarm(
            hour: components.hour!,
            minute: components.minute!,
            isEnabled: true,
            repeatDays: []
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire, "활성화된 알람은 다음 발화 시간이 있어야 함")
        XCTAssertGreaterThan(nextFire!, now, "다음 발화 시간은 현재보다 미래여야 함")

        // 시간 차이가 대략 1시간 정도인지 확인 (±2분 허용)
        let timeDiff = nextFire!.timeIntervalSince(now)
        XCTAssertTrue(timeDiff > 3480 && timeDiff < 3720, "시간 차이는 약 1시간(3600초)이어야 함")
    }

    func test_nextFireDate_과거시간_반복없음_다음날로계산() {
        let calendar = Calendar.current
        let now = Date()

        // 1시간 전 시간으로 알람 설정
        let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now)!
        let components = calendar.dateComponents([.hour, .minute], from: oneHourAgo)

        let alarm = Alarm(
            hour: components.hour!,
            minute: components.minute!,
            isEnabled: true,
            repeatDays: []
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire, "과거 시간도 다음날로 예약되어야 함")
        XCTAssertGreaterThan(nextFire!, now, "다음 발화 시간은 현재보다 미래여야 함")

        // 대략 23시간 후 (다음날 같은 시간)
        // 초를 0으로 설정하므로, 현재 시간의 초에 따라 22:59 ~ 23:01 범위
        let timeDiff = nextFire!.timeIntervalSince(now)
        XCTAssertTrue(timeDiff > 82740 && timeDiff < 83460, "다음날 같은 시간으로 예약되어야 함 (~23시간, ±1분)")
    }

    func test_nextFireDate_비활성화_알람_nil반환() {
        let alarm = Alarm(
            hour: 9,
            minute: 0,
            isEnabled: false,
            repeatDays: []
        )

        XCTAssertNil(alarm.nextFireDate, "비활성화된 알람은 nil을 반환해야 함")
    }

    // MARK: - Repeating Alarm Tests

    func test_nextFireDate_매일반복_다음알람시간계산() {
        let calendar = Calendar.current
        let now = Date()

        // 1시간 후로 설정하고 매일 반복
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now)!
        let components = calendar.dateComponents([.hour, .minute], from: oneHourLater)

        let alarm = Alarm(
            hour: components.hour!,
            minute: components.minute!,
            isEnabled: true,
            repeatDays: [0, 1, 2, 3, 4, 5, 6] // 일~토
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire, "매일 반복 알람은 다음 발화 시간이 있어야 함")
        XCTAssertGreaterThan(nextFire!, now, "다음 발화 시간은 현재보다 미래여야 함")
    }

    func test_nextFireDate_평일반복_오늘이평일이면오늘() throws {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) - 1 // 0=일요일

        // 평일(월~금: 1,2,3,4,5)이 아니면 테스트 스킵
        guard (1...5).contains(weekday) else {
            throw XCTSkip("이 테스트는 평일에만 실행됩니다")
        }

        // 1시간 후로 설정하고 평일만 반복
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now)!
        let components = calendar.dateComponents([.hour, .minute], from: oneHourLater)

        let alarm = Alarm(
            hour: components.hour!,
            minute: components.minute!,
            isEnabled: true,
            repeatDays: [1, 2, 3, 4, 5] // 월~금
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire)

        // 다음 발화일이 오늘인지 확인
        let nextFireDay = calendar.startOfDay(for: nextFire!)
        let today = calendar.startOfDay(for: now)
        XCTAssertEqual(nextFireDay, today, "평일 반복 알람은 오늘 발화해야 함")
    }

    func test_nextFireDate_주말반복_오늘이주말이아니면다음주말() throws {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) - 1 // 0=일요일

        // 주말(토,일: 6,0)이면 테스트 스킵
        guard !(weekday == 0 || weekday == 6) else {
            throw XCTSkip("이 테스트는 평일에만 실행됩니다")
        }

        // 주말만 반복
        let alarm = Alarm(
            hour: 9,
            minute: 0,
            isEnabled: true,
            repeatDays: [0, 6] // 일, 토
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire)

        // 다음 발화일의 요일 확인
        let nextFireWeekday = calendar.component(.weekday, from: nextFire!) - 1
        XCTAssertTrue(nextFireWeekday == 0 || nextFireWeekday == 6, "다음 발화일은 주말이어야 함")
        XCTAssertGreaterThan(nextFire!, now)
    }

    // MARK: - Edge Cases

    func test_nextFireDate_자정_정확히계산() {
        let alarm = Alarm(
            hour: 0,
            minute: 0,
            isEnabled: true,
            repeatDays: []
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: nextFire!)

        XCTAssertEqual(components.hour, 0, "시간은 0시여야 함")
        XCTAssertEqual(components.minute, 0, "분은 0분이어야 함")
    }

    func test_nextFireDate_23시59분_정확히계산() {
        let alarm = Alarm(
            hour: 23,
            minute: 59,
            isEnabled: true,
            repeatDays: []
        )

        let nextFire = alarm.nextFireDate

        XCTAssertNotNil(nextFire)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: nextFire!)

        XCTAssertEqual(components.hour, 23, "시간은 23시여야 함")
        XCTAssertEqual(components.minute, 59, "분은 59분이어야 함")
    }

    // MARK: - Helper Methods

    private func createAlarm(hour: Int, minute: Int, isEnabled: Bool = true, repeatDays: [Int] = []) -> Alarm {
        return Alarm(
            hour: hour,
            minute: minute,
            isEnabled: isEnabled,
            repeatDays: repeatDays
        )
    }
}
