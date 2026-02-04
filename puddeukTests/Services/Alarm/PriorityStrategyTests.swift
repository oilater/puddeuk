import XCTest
@testable import puddeuk

final class PriorityStrategyTests: XCTestCase {
    var sut: TimeBasedPriorityStrategy!

    override func setUp() {
        super.setUp()
        sut = TimeBasedPriorityStrategy()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }


    func test_calculatePriority_lessThan24Hours_returnsCritical() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 12) // 12 hours

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .critical, "24시간 이내 알람은 critical 우선순위를 가져야 함")
    }

    func test_calculatePriority_exactly24Hours_returnsCritical() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 24)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .high, "24시간은 high 우선순위")
    }

    func test_calculatePriority_between24And48Hours_returnsHigh() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 36)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .high, "24-48시간 사이는 high 우선순위")
    }

    func test_calculatePriority_between2And7Days_returnsMedium() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 24 * 3)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .medium, "2-7일 사이는 medium 우선순위")
    }

    func test_calculatePriority_moreThan7Days_returnsLow() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 24 * 10)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .low, "7일 이후는 low 우선순위")
    }

    func test_calculatePriority_pastDate_returnsCritical() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(-3600) // 1시간 전

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)

        XCTAssertEqual(priority, .critical, "과거 시간은 critical (즉시 발화)")
    }


    func test_determineChainCount_critical_returns8() {
        let chainCount = sut.determineChainCount(for: .critical)

        XCTAssertEqual(chainCount, 8, "Critical 우선순위는 8개 체인")
    }

    func test_determineChainCount_high_returns8() {
        let chainCount = sut.determineChainCount(for: .high)

        XCTAssertEqual(chainCount, 8, "High 우선순위는 8개 체인")
    }

    func test_determineChainCount_medium_returns4() {
        let chainCount = sut.determineChainCount(for: .medium)

        XCTAssertEqual(chainCount, 4, "Medium 우선순위는 4개 체인")
    }

    func test_determineChainCount_low_returns2() {
        let chainCount = sut.determineChainCount(for: .low)

        XCTAssertEqual(chainCount, 2, "Low 우선순위는 2개 체인")
    }


    func test_priorityOrdering_correctOrder() {
        let priorities: [ScheduledEventPriority] = [.low, .critical, .medium, .high]

        let sorted = priorities.sorted()

        XCTAssertEqual(sorted, [.low, .medium, .high, .critical], "우선순위 정렬이 올바른지 확인")
    }


    func test_fullWorkflow_immediateToCritical() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)
        let chainCount = sut.determineChainCount(for: priority)

        XCTAssertEqual(priority, .critical)
        XCTAssertEqual(chainCount, 8)
    }

    func test_fullWorkflow_distantToLow() {
        let referenceDate = Date()
        let fireDate = referenceDate.addingTimeInterval(3600 * 24 * 30)

        let priority = sut.calculatePriority(for: fireDate, from: referenceDate)
        let chainCount = sut.determineChainCount(for: priority)

        XCTAssertEqual(priority, .low)
        XCTAssertEqual(chainCount, 2)
    }
}
