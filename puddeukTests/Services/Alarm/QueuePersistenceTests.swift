import XCTest
import SwiftData
@testable import puddeuk

@MainActor
final class QueuePersistenceTests: XCTestCase {
    var sut: QueuePersistence!
    var mockModelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        sut = QueuePersistence()

        let schema = Schema([QueueState.self, Alarm.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        mockModelContext = ModelContext(container)
    }

    override func tearDown() {
        sut = nil
        mockModelContext = nil
        super.tearDown()
    }


    func test_save_createsQueueState() async {
        let identifiers: Set<String> = ["alarm-1-chain-0", "alarm-2-chain-1"]
        let version = 5

        await sut.save(scheduledIdentifiers: identifiers, version: version, to: mockModelContext)

        let descriptor = FetchDescriptor<QueueState>()
        let states = try? mockModelContext.fetch(descriptor)

        XCTAssertEqual(states?.count, 1, "QueueState가 1개 저장되어야 함")
        XCTAssertEqual(Set(states?.first?.scheduledIdentifiers ?? []), identifiers)
        XCTAssertEqual(states?.first?.queueVersion, version)
    }

    func test_save_replacesOldState() async {
        await sut.save(scheduledIdentifiers: ["old-1"], version: 1, to: mockModelContext)

        let newIdentifiers: Set<String> = ["new-1", "new-2"]
        await sut.save(scheduledIdentifiers: newIdentifiers, version: 2, to: mockModelContext)

        let descriptor = FetchDescriptor<QueueState>()
        let states = try? mockModelContext.fetch(descriptor)

        XCTAssertEqual(states?.count, 1, "QueueState는 항상 1개만 존재해야 함")
        XCTAssertEqual(Set(states?.first?.scheduledIdentifiers ?? []), newIdentifiers)
        XCTAssertEqual(states?.first?.queueVersion, 2)
    }

    func test_save_emptyIdentifiers_savesSuccessfully() async {
        let identifiers: Set<String> = []
        let version = 0

        await sut.save(scheduledIdentifiers: identifiers, version: version, to: mockModelContext)

        let descriptor = FetchDescriptor<QueueState>()
        let states = try? mockModelContext.fetch(descriptor)

        XCTAssertEqual(states?.count, 1)
        XCTAssertTrue(states?.first?.scheduledIdentifiers.isEmpty ?? false)
    }

    func test_save_setsLastSyncTimestamp() async {
        let before = Date()
        let identifiers: Set<String> = ["test-1"]

        await sut.save(scheduledIdentifiers: identifiers, version: 1, to: mockModelContext)

        let descriptor = FetchDescriptor<QueueState>()
        let states = try? mockModelContext.fetch(descriptor)
        let timestamp = states?.first?.lastSyncTimestamp

        XCTAssertNotNil(timestamp)
        XCTAssertGreaterThanOrEqual(timestamp ?? Date.distantPast, before, "타임스탬프가 저장 시점 이후여야 함")
    }


    func test_load_noSavedState_returnsNil() async {
        let result = await sut.load(from: mockModelContext)

        XCTAssertNil(result, "저장된 상태가 없으면 nil 반환")
    }

    func test_load_savedState_returnsCorrectData() async {
        let identifiers: Set<String> = ["alarm-1", "alarm-2", "alarm-3"]
        let version = 10
        await sut.save(scheduledIdentifiers: identifiers, version: version, to: mockModelContext)

        let result = await sut.load(from: mockModelContext)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.scheduledIdentifiers, identifiers)
        XCTAssertEqual(result?.version, version)
    }

    func test_load_multipleStates_returnsFirstOne() async {
        let state1 = QueueState()
        state1.scheduledIdentifiers = ["state-1"]
        state1.queueVersion = 1
        mockModelContext.insert(state1)

        let state2 = QueueState()
        state2.scheduledIdentifiers = ["state-2"]
        state2.queueVersion = 2
        mockModelContext.insert(state2)

        try? mockModelContext.save()

        let result = await sut.load(from: mockModelContext)

        XCTAssertNotNil(result)
    }


    func test_saveAndLoad_roundTrip() async {
        let originalIdentifiers: Set<String> = ["id-1", "id-2", "id-3"]
        let originalVersion = 42

        await sut.save(
            scheduledIdentifiers: originalIdentifiers,
            version: originalVersion,
            to: mockModelContext
        )

        let result = await sut.load(from: mockModelContext)

        XCTAssertEqual(result?.scheduledIdentifiers, originalIdentifiers)
        XCTAssertEqual(result?.version, originalVersion)
    }

    func test_multipleSaveAndLoad_maintainsLatestState() async {
        await sut.save(scheduledIdentifiers: ["v1"], version: 1, to: mockModelContext)
        await sut.save(scheduledIdentifiers: ["v2-1", "v2-2"], version: 2, to: mockModelContext)
        await sut.save(scheduledIdentifiers: ["v3-1", "v3-2", "v3-3"], version: 3, to: mockModelContext)

        let result = await sut.load(from: mockModelContext)

        XCTAssertEqual(result?.scheduledIdentifiers.count, 3)
        XCTAssertEqual(result?.version, 3)
    }

    func test_saveWithLargeIdentifierSet_succeeds() async {
        let largeSet = Set((0..<480).map { "alarm-\($0)-chain-0" })

        await sut.save(scheduledIdentifiers: largeSet, version: 1, to: mockModelContext)

        let result = await sut.load(from: mockModelContext)
        XCTAssertEqual(result?.scheduledIdentifiers.count, 480)
    }
}
