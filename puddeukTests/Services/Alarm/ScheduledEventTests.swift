import XCTest
@testable import puddeuk

final class ScheduledEventTests: XCTestCase {

    func test_comparableByFireDate_earlierDateIsLess() {
        let earlyDate = Date()
        let lateDate = earlyDate.addingTimeInterval(3600)

        let event1 = ScheduledEvent(
            id: "event-1",
            alarmId: UUID(),
            fireDate: earlyDate,
            chainIndex: 0,
            priority: .medium,
            isScheduled: false
        )

        let event2 = ScheduledEvent(
            id: "event-2",
            alarmId: UUID(),
            fireDate: lateDate,
            chainIndex: 0,
            priority: .medium,
            isScheduled: false
        )

        XCTAssertLessThan(event1, event2, "더 이른 시간의 이벤트가 작아야 함")
    }

    func test_sorting_ordersByFireDate() {
        let baseDate = Date()

        let event1 = ScheduledEvent(
            id: "1", alarmId: UUID(),
            fireDate: baseDate.addingTimeInterval(3600),
            chainIndex: 0, priority: .medium, isScheduled: false
        )

        let event2 = ScheduledEvent(
            id: "2", alarmId: UUID(),
            fireDate: baseDate.addingTimeInterval(7200),
            chainIndex: 0, priority: .medium, isScheduled: false
        )

        let event3 = ScheduledEvent(
            id: "3", alarmId: UUID(),
            fireDate: baseDate.addingTimeInterval(1800),
            chainIndex: 0, priority: .medium, isScheduled: false
        )

        let events = [event2, event1, event3]

        let sorted = events.sorted()

        XCTAssertEqual(sorted[0].id, "3", "가장 이른 시간")
        XCTAssertEqual(sorted[1].id, "1", "중간 시간")
        XCTAssertEqual(sorted[2].id, "2", "가장 늦은 시간")
    }


    func test_sendable_canBeUsedAcrossActors() async {
        let event = ScheduledEvent(
            id: "test",
            alarmId: UUID(),
            fireDate: Date(),
            chainIndex: 0,
            priority: .critical,
            isScheduled: false
        )

        await Task {
            XCTAssertEqual(event.id, "test")
        }.value
    }


    func test_initialization_setsAllProperties() {
        let id = "test-event-id"
        let alarmId = UUID()
        let fireDate = Date()
        let chainIndex = 5
        let priority = ScheduledEventPriority.high
        let isScheduled = true

        let event = ScheduledEvent(
            id: id,
            alarmId: alarmId,
            fireDate: fireDate,
            chainIndex: chainIndex,
            priority: priority,
            isScheduled: isScheduled
        )

        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.alarmId, alarmId)
        XCTAssertEqual(event.fireDate, fireDate)
        XCTAssertEqual(event.chainIndex, chainIndex)
        XCTAssertEqual(event.priority, priority)
        XCTAssertEqual(event.isScheduled, isScheduled)
    }

    func test_isScheduled_canBeMutated() {
        var event = ScheduledEvent(
            id: "test",
            alarmId: UUID(),
            fireDate: Date(),
            chainIndex: 0,
            priority: .medium,
            isScheduled: false
        )

        event.isScheduled = true

        XCTAssertTrue(event.isScheduled)
    }


    func test_chainEvents_sortedCorrectly() {
        let alarmId = UUID()
        let baseDate = Date()
        let interval: TimeInterval = 26.5

        var events: [ScheduledEvent] = []
        for i in 0..<8 {
            let event = ScheduledEvent(
                id: "\(alarmId.uuidString)-chain-\(i)",
                alarmId: alarmId,
                fireDate: baseDate.addingTimeInterval(interval * Double(i)),
                chainIndex: i,
                priority: .critical,
                isScheduled: false
            )
            events.append(event)
        }

        let shuffled = events.shuffled()
        let sorted = shuffled.sorted()

        for i in 0..<8 {
            XCTAssertEqual(sorted[i].chainIndex, i)
        }
    }
}
