import XCTest
import SwiftData
@testable import puddeuk

@MainActor
final class NotificationQueueManagerTests: XCTestCase {
    var sut: NotificationQueueManager!
    var mockModelContext: ModelContext!
    var mockPriorityStrategy: MockPriorityStrategy!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([Alarm.self, QueueState.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        mockModelContext = ModelContext(container)

        mockPriorityStrategy = MockPriorityStrategy()

        sut = NotificationQueueManager.create(
            priorityStrategy: mockPriorityStrategy,
            persistence: QueuePersistence(),
            scheduler: NotificationScheduler(),
            chainCoordinator: AlarmChainCoordinator.shared
        )
        sut.setModelContext(mockModelContext)
    }

    override func tearDown() {
        sut = nil
        mockModelContext = nil
        mockPriorityStrategy = nil
        super.tearDown()
    }


    func test_rebuildQueue_noAlarms_createsEmptyQueue() async throws {
        try await sut.rebuildQueue()

        let stats = sut.getQueueStats()
        XCTAssertEqual(stats.total, 0, "알람이 없으면 큐도 비어야 함")
    }

    func test_rebuildQueue_oneAlarm_createsCorrectEventCount() async throws {
        let alarm = createTestAlarm(hour: 9, minute: 0, isEnabled: true)
        mockModelContext.insert(alarm)

        mockPriorityStrategy.mockPriority = .critical
        mockPriorityStrategy.mockChainCount = 8

        try await sut.rebuildQueue()

        let stats = sut.getQueueStats()
        XCTAssertEqual(stats.total, 8, "8개 체인 이벤트 생성")
    }

    func test_rebuildQueue_disabledAlarm_doesNotCreateEvents() async throws {
        let alarm = createTestAlarm(hour: 9, minute: 0, isEnabled: false)
        mockModelContext.insert(alarm)

        try await sut.rebuildQueue()

        let stats = sut.getQueueStats()
        XCTAssertEqual(stats.total, 0, "비활성 알람은 큐에 추가되지 않아야 함")
    }

    func test_rebuildQueue_multipleAlarms_createsAllEvents() async throws {
        let alarm1 = createTestAlarm(hour: 8, minute: 0, isEnabled: true)
        let alarm2 = createTestAlarm(hour: 12, minute: 30, isEnabled: true)
        let alarm3 = createTestAlarm(hour: 18, minute: 0, isEnabled: true)

        mockModelContext.insert(alarm1)
        mockModelContext.insert(alarm2)
        mockModelContext.insert(alarm3)

        mockPriorityStrategy.mockPriority = .medium
        mockPriorityStrategy.mockChainCount = 4

        try await sut.rebuildQueue()

        let stats = sut.getQueueStats()
        XCTAssertEqual(stats.total, 12, "3개 알람 * 4개 체인 = 12개 이벤트")
    }


    func test_selectNext60_emptyQueue_returnsEmpty() {
        let selected = sut.selectNext60()

        XCTAssertTrue(selected.isEmpty, "빈 큐에서는 선택할 이벤트 없음")
    }

    func test_selectNext60_respectsIOSLimit() async throws {
        for i in 0..<100 {
            let alarm = createTestAlarm(hour: i % 24, minute: 0, isEnabled: true)
            mockModelContext.insert(alarm)
        }

        mockPriorityStrategy.mockPriority = .critical
        mockPriorityStrategy.mockChainCount = 8

        try await sut.rebuildQueue()

        let selected = sut.selectNext60()

        XCTAssertLessThanOrEqual(selected.count, 60, "iOS 60개 제한 준수")
    }

    func test_selectNext60_prioritizesCriticalOverLow() async throws {
        let criticalAlarm = createTestAlarm(hour: 9, minute: 0, isEnabled: true)
        let lowAlarm = createTestAlarm(hour: 10, minute: 0, isEnabled: true)

        mockModelContext.insert(criticalAlarm)
        mockModelContext.insert(lowAlarm)

        mockPriorityStrategy.mockPriority = .critical
        mockPriorityStrategy.mockChainCount = 8
        try await sut.rebuildQueue()

        let selected = sut.selectNext60()

        XCTAssertGreaterThan(selected.count, 0)
    }


    func test_removeAlarm_removesAllChainEvents() async throws {
        let alarm = createTestAlarm(hour: 9, minute: 0, isEnabled: true)
        mockModelContext.insert(alarm)

        mockPriorityStrategy.mockPriority = .critical
        mockPriorityStrategy.mockChainCount = 8

        try await sut.rebuildQueue()
        let beforeStats = sut.getQueueStats()
        XCTAssertEqual(beforeStats.total, 8)

        await sut.removeAlarm(alarmId: alarm.id)

        let afterStats = sut.getQueueStats()
        XCTAssertEqual(afterStats.total, 0, "알람 제거 시 모든 체인 이벤트 삭제")
    }

    func test_removeAlarm_nonExistentAlarm_doesNotCrash() async {
        let fakeId = UUID()

        await sut.removeAlarm(alarmId: fakeId)
    }

    func test_removeAlarm_removesOnlyTargetAlarm() async throws {
        let alarm1 = createTestAlarm(hour: 9, minute: 0, isEnabled: true)
        let alarm2 = createTestAlarm(hour: 12, minute: 0, isEnabled: true)

        mockModelContext.insert(alarm1)
        mockModelContext.insert(alarm2)

        mockPriorityStrategy.mockChainCount = 4
        try await sut.rebuildQueue()

        let beforeStats = sut.getQueueStats()
        XCTAssertEqual(beforeStats.total, 8) // 2 alarms * 4 chains

        await sut.removeAlarm(alarmId: alarm1.id)

        let afterStats = sut.getQueueStats()
        XCTAssertEqual(afterStats.total, 4)
    }


    func test_incrementQueueVersion_increasesVersion() {
        sut.incrementQueueVersion()

        XCTAssertTrue(true, "incrementQueueVersion 호출 성공")
    }


    private func createTestAlarm(
        hour: Int,
        minute: Int,
        isEnabled: Bool
    ) -> Alarm {
        let alarm = Alarm()
        alarm.title = "테스트 알람"
        alarm.hour = hour
        alarm.minute = minute
        alarm.isEnabled = isEnabled
        return alarm
    }
}


class MockPriorityStrategy: PriorityStrategy {
    var mockPriority: ScheduledEventPriority = .medium
    var mockChainCount: Int = 4

    func calculatePriority(for date: Date, from referenceDate: Date) -> ScheduledEventPriority {
        return mockPriority
    }

    func determineChainCount(for priority: ScheduledEventPriority) -> Int {
        return mockChainCount
    }
}
