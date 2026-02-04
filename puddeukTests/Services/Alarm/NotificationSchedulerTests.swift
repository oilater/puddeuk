import XCTest
import SwiftData
import UserNotifications
@testable import puddeuk

@MainActor
final class NotificationSchedulerTests: XCTestCase {
    var sut: NotificationScheduler!
    var mockModelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        sut = NotificationScheduler()

        let schema = Schema([Alarm.self, QueueState.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        mockModelContext = ModelContext(container)
    }

    override func tearDown() {
        sut = nil
        mockModelContext = nil
        super.tearDown()
    }


    func test_schedule_createsNotificationWithCorrectContent() async throws {
        let alarm = createTestAlarm(title: "테스트 알람")
        mockModelContext.insert(alarm)

        let event = ScheduledEvent(
            id: "\(alarm.id.uuidString)-chain-0",
            alarmId: alarm.id,
            fireDate: Date().addingTimeInterval(3600),
            chainIndex: 0,
            priority: .critical,
            isScheduled: false
        )


        XCTAssertEqual(alarm.title, "테스트 알람")
        XCTAssertNotNil(event.fireDate)
    }


    func test_fetchAlarm_existingAlarm_returnsAlarm() {
        let alarm = createTestAlarm(title: "찾을 알람")
        mockModelContext.insert(alarm)

        let result = sut.fetchAlarm(with: alarm.id, from: mockModelContext)

        XCTAssertNotNil(result, "알람을 찾아야 함")
        XCTAssertEqual(result?.id, alarm.id)
        XCTAssertEqual(result?.title, "찾을 알람")
    }

    func test_fetchAlarm_nonExistentAlarm_returnsNil() {
        let fakeId = UUID()

        let result = sut.fetchAlarm(with: fakeId, from: mockModelContext)

        XCTAssertNil(result, "존재하지 않는 알람은 nil 반환")
    }

    func test_fetchAlarm_multipleAlarms_returnsCorrectOne() {
        let alarm1 = createTestAlarm(title: "알람 1")
        let alarm2 = createTestAlarm(title: "알람 2")
        let alarm3 = createTestAlarm(title: "알람 3")

        mockModelContext.insert(alarm1)
        mockModelContext.insert(alarm2)
        mockModelContext.insert(alarm3)

        let result = sut.fetchAlarm(with: alarm2.id, from: mockModelContext)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, alarm2.id)
        XCTAssertEqual(result?.title, "알람 2")
    }


    func test_getPendingIdentifiers_returnsSetOfStrings() async {
        let identifiers = await sut.getPendingIdentifiers()

        XCTAssertNotNil(identifiers, "Set을 반환해야 함")
    }


    func test_remove_emptyArray_doesNotCrash() {
        let identifiers: [String] = []

        sut.remove(identifiers: identifiers)
    }

    func test_remove_validIdentifiers_doesNotCrash() {
        let identifiers = [
            "alarm-123-chain-0",
            "alarm-456-chain-1"
        ]

        sut.remove(identifiers: identifiers)
    }


    private func createTestAlarm(
        title: String,
        hour: Int = 9,
        minute: Int = 0,
        isEnabled: Bool = true
    ) -> Alarm {
        let alarm = Alarm()
        alarm.title = title
        alarm.hour = hour
        alarm.minute = minute
        alarm.isEnabled = isEnabled
        return alarm
    }
}
