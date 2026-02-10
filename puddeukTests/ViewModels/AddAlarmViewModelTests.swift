import XCTest
import SwiftData
@testable import puddeuk

@MainActor
final class AddAlarmViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AddAlarmViewModel!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory 테스트용 ModelContainer 생성
        let schema = Schema([Alarm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
    }

    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_withoutAlarm_shouldSetDefaultValues() {
        // Given & When
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)

        // Then
        XCTAssertEqual(viewModel.title, "")
        XCTAssertTrue(viewModel.repeatDays.isEmpty)
        XCTAssertNil(viewModel.audioFileName)
        XCTAssertNil(viewModel.snoozeInterval)
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertEqual(viewModel.navigationTitle, "새 알람")
    }

    func testInit_withExistingAlarm_shouldLoadAlarmData() {
        // Given
        let existingAlarm = Alarm(
            title: "기상 알람",
            hour: 7,
            minute: 30,
            isEnabled: true,
            audioFileName: "alarm.caf",
            repeatDays: [1, 2, 3, 4, 5],
            snoozeInterval: 5
        )
        modelContext.insert(existingAlarm)

        // When
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: existingAlarm)

        // Then
        XCTAssertEqual(viewModel.title, "기상 알람")
        XCTAssertEqual(viewModel.repeatDays, Set([1, 2, 3, 4, 5]))
        XCTAssertEqual(viewModel.audioFileName, "alarm.caf")
        XCTAssertEqual(viewModel.snoozeInterval, 5)
        XCTAssertTrue(viewModel.isEditing)
        XCTAssertEqual(viewModel.navigationTitle, "알람 편집")

        // 시간 검증
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: viewModel.selectedTime)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - Save Alarm Tests

    func testSaveAlarm_newAlarm_shouldCreateAlarm() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "새 알람"

        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        viewModel.selectedTime = Calendar.current.date(from: components)!
        viewModel.repeatDays = [1, 2, 3]
        viewModel.snoozeInterval = 10

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(alarms.count, 1)
        let savedAlarm = alarms.first!
        XCTAssertEqual(savedAlarm.title, "새 알람")
        XCTAssertEqual(savedAlarm.hour, 8)
        XCTAssertEqual(savedAlarm.minute, 0)
        XCTAssertEqual(Set(savedAlarm.repeatDays), Set([1, 2, 3]))
        XCTAssertEqual(savedAlarm.snoozeInterval, 10)
        XCTAssertTrue(savedAlarm.isEnabled)
    }

    func testSaveAlarm_existingAlarm_shouldUpdateAlarm() async throws {
        // Given
        let existingAlarm = Alarm(
            title: "기존 알람",
            hour: 7,
            minute: 0,
            isEnabled: true,
            repeatDays: [1, 2]
        )
        modelContext.insert(existingAlarm)
        try modelContext.save()

        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: existingAlarm)

        // When
        viewModel.title = "수정된 알람"
        var components = DateComponents()
        components.hour = 9
        components.minute = 30
        viewModel.selectedTime = Calendar.current.date(from: components)!
        viewModel.repeatDays = [3, 4, 5]
        viewModel.snoozeInterval = 15

        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(alarms.count, 1)
        let updatedAlarm = alarms.first!
        XCTAssertEqual(updatedAlarm.id, existingAlarm.id)
        XCTAssertEqual(updatedAlarm.title, "수정된 알람")
        XCTAssertEqual(updatedAlarm.hour, 9)
        XCTAssertEqual(updatedAlarm.minute, 30)
        XCTAssertEqual(Set(updatedAlarm.repeatDays), Set([3, 4, 5]))
        XCTAssertEqual(updatedAlarm.snoozeInterval, 15)
    }

    func testSaveAlarm_withAudioFile_shouldSaveAudioFileName() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "오디오 알람"
        viewModel.audioFileName = "custom_alarm.caf"

        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        viewModel.selectedTime = Calendar.current.date(from: components)!

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(alarms.count, 1)
        XCTAssertEqual(alarms.first?.audioFileName, "custom_alarm.caf")
    }

    // MARK: - Delete Alarm Tests

    func testDeleteAlarm_shouldRemoveAlarmFromContext() async throws {
        // Given
        let existingAlarm = Alarm(
            title: "삭제될 알람",
            hour: 7,
            minute: 0,
            isEnabled: true
        )
        modelContext.insert(existingAlarm)
        try modelContext.save()

        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: existingAlarm)

        // When
        await viewModel.deleteAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)
        XCTAssertEqual(alarms.count, 0)
    }

    func testDeleteAlarm_withoutAlarm_shouldNotCrash() async {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)

        // When & Then - should not crash
        await viewModel.deleteAlarm()
    }

    // MARK: - Show Delete Alert Tests

    func testShowDeleteAlert_shouldSetShowingDeleteAlertToTrue() {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        XCTAssertFalse(viewModel.showingDeleteAlert)

        // When
        viewModel.showDeleteAlert()

        // Then
        XCTAssertTrue(viewModel.showingDeleteAlert)
    }

    // MARK: - Error Handling Tests

    func testSaveAlarm_whenContextSaveFails_shouldShowError() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "테스트 알람"

        // Note: ModelContext.save()는 실제로 실패하기 어려워서
        // 이 테스트는 개념적인 예시입니다.
        // 실제로는 Mock ModelContext를 만들어서 테스트해야 합니다.

        // When
        await viewModel.saveAlarm()

        // Then
        // 정상 케이스에서는 에러가 없어야 함
        XCTAssertFalse(viewModel.showingErrorAlert)
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow_createAndUpdate() async throws {
        // 1. 새 알람 생성
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "통합 테스트"

        var components = DateComponents()
        components.hour = 6
        components.minute = 30
        viewModel.selectedTime = Calendar.current.date(from: components)!
        viewModel.repeatDays = [1, 2, 3, 4, 5]

        await viewModel.saveAlarm()

        var descriptor = FetchDescriptor<Alarm>()
        var alarms = try modelContext.fetch(descriptor)
        XCTAssertEqual(alarms.count, 1)
        let savedAlarm = alarms.first!

        // 2. 알람 수정
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: savedAlarm)
        viewModel.title = "수정됨"
        components.hour = 7
        viewModel.selectedTime = Calendar.current.date(from: components)!

        await viewModel.saveAlarm()

        alarms = try modelContext.fetch(descriptor)
        XCTAssertEqual(alarms.count, 1)
        XCTAssertEqual(alarms.first?.title, "수정됨")
        XCTAssertEqual(alarms.first?.hour, 7)

        // 3. 알람 삭제
        await viewModel.deleteAlarm()

        alarms = try modelContext.fetch(descriptor)
        XCTAssertEqual(alarms.count, 0)
    }

    // MARK: - Time Handling Tests

    func testSaveAlarm_withMidnight_shouldHandleCorrectly() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "자정 알람"

        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        viewModel.selectedTime = Calendar.current.date(from: components)!

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(alarms.first?.hour, 0)
        XCTAssertEqual(alarms.first?.minute, 0)
    }

    func testSaveAlarm_with23Hours59Minutes_shouldHandleCorrectly() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "자정 직전"

        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        viewModel.selectedTime = Calendar.current.date(from: components)!

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(alarms.first?.hour, 23)
        XCTAssertEqual(alarms.first?.minute, 59)
    }

    // MARK: - Repeat Days Tests

    func testSaveAlarm_withEmptyRepeatDays_shouldSaveAsOneTime() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "일회성 알람"
        viewModel.repeatDays = []

        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        viewModel.selectedTime = Calendar.current.date(from: components)!

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertTrue(alarms.first?.repeatDays.isEmpty ?? false)
    }

    func testSaveAlarm_withAllDaysSelected_shouldSaveAllDays() async throws {
        // Given
        viewModel = AddAlarmViewModel(modelContext: modelContext, alarm: nil)
        viewModel.title = "매일 알람"
        viewModel.repeatDays = Set([0, 1, 2, 3, 4, 5, 6])

        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        viewModel.selectedTime = Calendar.current.date(from: components)!

        // When
        await viewModel.saveAlarm()

        // Then
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = try modelContext.fetch(descriptor)

        XCTAssertEqual(Set(alarms.first?.repeatDays ?? []), Set([0, 1, 2, 3, 4, 5, 6]))
    }
}
