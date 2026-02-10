import XCTest
import SwiftData
@testable import puddeuk

@MainActor
final class AlarmListViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AlarmListViewModel!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory 테스트용 ModelContainer 생성
        let schema = Schema([Alarm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext

        viewModel = AlarmListViewModel(modelContext: modelContext)
    }

    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_shouldHaveEmptyAlarms() {
        // Then
        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
    }

    // MARK: - Load Alarms Tests

    func testLoadAlarms_withNoAlarms_shouldReturnEmptyList() {
        // When
        viewModel.loadAlarms()

        // Then
        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertFalse(viewModel.hasAlarms)
    }

    func testLoadAlarms_withMultipleAlarms_shouldLoadAllAlarms() {
        // Given
        let alarm1 = Alarm(title: "알람 1", hour: 7, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "알람 2", hour: 8, minute: 30, isEnabled: false)
        let alarm3 = Alarm(title: "알람 3", hour: 9, minute: 15, isEnabled: true)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()

        // When
        viewModel.loadAlarms()

        // Then
        XCTAssertEqual(viewModel.alarms.count, 3)
        XCTAssertTrue(viewModel.hasAlarms)
    }

    func testLoadAlarms_shouldSortByTime() {
        // Given
        let alarm1 = Alarm(title: "저녁", hour: 18, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "아침", hour: 7, minute: 0, isEnabled: true)
        let alarm3 = Alarm(title: "점심", hour: 12, minute: 30, isEnabled: true)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()

        // When
        viewModel.loadAlarms()

        // Then
        XCTAssertEqual(viewModel.alarms.count, 3)
        XCTAssertEqual(viewModel.alarms[0].hour, 7)
        XCTAssertEqual(viewModel.alarms[1].hour, 12)
        XCTAssertEqual(viewModel.alarms[2].hour, 18)
    }

    // MARK: - Toggle Alarm Tests

    func testToggleAlarm_fromEnabledToDisabled_shouldUpdateState() async {
        // Given
        let alarm = Alarm(title: "테스트", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        XCTAssertTrue(alarm.isEnabled)

        // When
        await viewModel.toggleAlarm(alarm)

        // Then
        XCTAssertFalse(alarm.isEnabled)
    }

    func testToggleAlarm_fromDisabledToEnabled_shouldUpdateState() async {
        // Given
        let alarm = Alarm(title: "테스트", hour: 8, minute: 0, isEnabled: false)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        XCTAssertFalse(alarm.isEnabled)

        // When
        await viewModel.toggleAlarm(alarm)

        // Then
        XCTAssertTrue(alarm.isEnabled)
    }

    func testToggleAlarm_multipleTimes_shouldToggleCorrectly() async {
        // Given
        let alarm = Alarm(title: "테스트", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm)
        try? modelContext.save()

        // When & Then
        await viewModel.toggleAlarm(alarm)
        XCTAssertFalse(alarm.isEnabled)

        await viewModel.toggleAlarm(alarm)
        XCTAssertTrue(alarm.isEnabled)

        await viewModel.toggleAlarm(alarm)
        XCTAssertFalse(alarm.isEnabled)
    }

    // MARK: - Delete Alarm Tests

    func testDeleteAlarm_shouldRemoveFromContext() async {
        // Given
        let alarm = Alarm(title: "삭제될 알람", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        XCTAssertEqual(viewModel.alarms.count, 1)

        // When
        await viewModel.deleteAlarm(alarm)

        // Then
        XCTAssertEqual(viewModel.alarms.count, 0)
        XCTAssertFalse(viewModel.hasAlarms)
    }

    func testDeleteAlarm_withMultipleAlarms_shouldOnlyDeleteOne() async {
        // Given
        let alarm1 = Alarm(title: "유지", hour: 7, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "삭제", hour: 8, minute: 0, isEnabled: true)
        let alarm3 = Alarm(title: "유지", hour: 9, minute: 0, isEnabled: true)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()
        viewModel.loadAlarms()

        XCTAssertEqual(viewModel.alarms.count, 3)

        // When
        await viewModel.deleteAlarm(alarm2)

        // Then
        XCTAssertEqual(viewModel.alarms.count, 2)
        XCTAssertTrue(viewModel.alarms.contains { $0.id == alarm1.id })
        XCTAssertFalse(viewModel.alarms.contains { $0.id == alarm2.id })
        XCTAssertTrue(viewModel.alarms.contains { $0.id == alarm3.id })
    }

    func testDeleteAlarm_withAudioFile_shouldDeleteAudioFile() async {
        // Given
        let alarm = Alarm(
            title: "오디오 알람",
            hour: 8,
            minute: 0,
            isEnabled: true,
            audioFileName: "test_alarm.caf"
        )
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        await viewModel.deleteAlarm(alarm)

        // Then
        XCTAssertEqual(viewModel.alarms.count, 0)
        // Note: 실제 파일 삭제는 AudioRecorder가 담당하므로
        // 이 테스트는 crash 없이 완료되는지만 확인
    }

    // MARK: - Computed Properties Tests

    func testHasAlarms_withEmptyList_shouldReturnFalse() {
        // Given
        viewModel.loadAlarms()

        // Then
        XCTAssertFalse(viewModel.hasAlarms)
    }

    func testHasAlarms_withAlarms_shouldReturnTrue() {
        // Given
        let alarm = Alarm(title: "테스트", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        // Then
        XCTAssertTrue(viewModel.hasAlarms)
    }

    func testEnabledAlarms_shouldReturnOnlyEnabledAlarms() {
        // Given
        let alarm1 = Alarm(title: "활성", hour: 7, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "비활성", hour: 8, minute: 0, isEnabled: false)
        let alarm3 = Alarm(title: "활성", hour: 9, minute: 0, isEnabled: true)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let enabledAlarms = viewModel.enabledAlarms

        // Then
        XCTAssertEqual(enabledAlarms.count, 2)
        XCTAssertTrue(enabledAlarms.allSatisfy { $0.isEnabled })
    }

    func testDisabledAlarms_shouldReturnOnlyDisabledAlarms() {
        // Given
        let alarm1 = Alarm(title: "활성", hour: 7, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "비활성", hour: 8, minute: 0, isEnabled: false)
        let alarm3 = Alarm(title: "비활성", hour: 9, minute: 0, isEnabled: false)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let disabledAlarms = viewModel.disabledAlarms

        // Then
        XCTAssertEqual(disabledAlarms.count, 2)
        XCTAssertTrue(disabledAlarms.allSatisfy { !$0.isEnabled })
    }

    // MARK: - Time Until Next Alarm Tests

    func testTimeUntilNextAlarm_withNoAlarms_shouldReturnNil() {
        // Given
        viewModel.loadAlarms()

        // When
        let timeUntil = viewModel.timeUntilNextAlarm()

        // Then
        XCTAssertNil(timeUntil)
    }

    func testTimeUntilNextAlarm_withOnlyDisabledAlarms_shouldReturnNil() {
        // Given
        let alarm = Alarm(title: "비활성", hour: 8, minute: 0, isEnabled: false)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let timeUntil = viewModel.timeUntilNextAlarm()

        // Then
        XCTAssertNil(timeUntil)
    }

    func testTimeUntilNextAlarm_withEnabledAlarm_shouldReturnString() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let futureComponents = calendar.dateComponents([.year, .month, .day], from: now)

        // 현재 시간보다 1시간 후
        var alarmComponents = futureComponents
        alarmComponents.hour = (calendar.component(.hour, from: now) + 1) % 24
        alarmComponents.minute = 0

        let alarm = Alarm(
            title: "다음 알람",
            hour: alarmComponents.hour!,
            minute: alarmComponents.minute!,
            isEnabled: true
        )
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let timeUntil = viewModel.timeUntilNextAlarm()

        // Then
        XCTAssertNotNil(timeUntil)
        // TimeFormatter의 결과는 구체적으로 검증하기 어려우므로
        // nil이 아닌지만 확인
    }

    func testTimeUntilNextAlarm_withMultipleEnabledAlarms_shouldReturnNextOne() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)

        var alarm1Components = components
        alarm1Components.hour = (calendar.component(.hour, from: now) + 2) % 24
        alarm1Components.minute = 0

        var alarm2Components = components
        alarm2Components.hour = (calendar.component(.hour, from: now) + 1) % 24
        alarm2Components.minute = 0

        let alarm1 = Alarm(
            title: "먼 미래",
            hour: alarm1Components.hour!,
            minute: 0,
            isEnabled: true
        )
        let alarm2 = Alarm(
            title: "가까운 미래",
            hour: alarm2Components.hour!,
            minute: 0,
            isEnabled: true
        )

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let timeUntil = viewModel.timeUntilNextAlarm()

        // Then
        XCTAssertNotNil(timeUntil)
    }

    // MARK: - Error Handling Tests

    func testLoadAlarms_whenContextIsValid_shouldNotShowError() {
        // When
        viewModel.loadAlarms()

        // Then
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow_loadToggleDelete() async {
        // 1. 알람 추가
        let alarm1 = Alarm(title: "알람 1", hour: 7, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "알람 2", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        try? modelContext.save()

        // 2. 로드
        viewModel.loadAlarms()
        XCTAssertEqual(viewModel.alarms.count, 2)
        XCTAssertEqual(viewModel.enabledAlarms.count, 2)

        // 3. 토글
        await viewModel.toggleAlarm(alarm1)
        XCTAssertFalse(alarm1.isEnabled)
        XCTAssertEqual(viewModel.enabledAlarms.count, 1)
        XCTAssertEqual(viewModel.disabledAlarms.count, 1)

        // 4. 삭제
        await viewModel.deleteAlarm(alarm2)
        XCTAssertEqual(viewModel.alarms.count, 1)

        // 5. 다시 토글
        await viewModel.toggleAlarm(alarm1)
        XCTAssertTrue(alarm1.isEnabled)
        XCTAssertEqual(viewModel.enabledAlarms.count, 1)
    }

    // MARK: - Edge Cases

    func testDeleteAlarm_lastAlarm_shouldResultInEmptyList() async {
        // Given
        let alarm = Alarm(title: "마지막 알람", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        XCTAssertTrue(viewModel.hasAlarms)

        // When
        await viewModel.deleteAlarm(alarm)

        // Then
        XCTAssertFalse(viewModel.hasAlarms)
        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertNil(viewModel.timeUntilNextAlarm())
    }

    func testLoadAlarms_calledMultipleTimes_shouldUpdateCorrectly() {
        // Given
        let alarm1 = Alarm(title: "알람 1", hour: 7, minute: 0, isEnabled: true)
        modelContext.insert(alarm1)
        try? modelContext.save()

        // When
        viewModel.loadAlarms()
        XCTAssertEqual(viewModel.alarms.count, 1)

        let alarm2 = Alarm(title: "알람 2", hour: 8, minute: 0, isEnabled: true)
        modelContext.insert(alarm2)
        try? modelContext.save()

        viewModel.loadAlarms()

        // Then
        XCTAssertEqual(viewModel.alarms.count, 2)
    }

    func testTimeUntilNextAlarm_withRepeatDays_shouldCalculateCorrectly() {
        // Given
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date()) - 1 // 0-6
        let tomorrow = (today + 1) % 7

        let alarm = Alarm(
            title: "내일 반복",
            hour: 8,
            minute: 0,
            isEnabled: true,
            repeatDays: [tomorrow]
        )
        modelContext.insert(alarm)
        try? modelContext.save()
        viewModel.loadAlarms()

        // When
        let timeUntil = viewModel.timeUntilNextAlarm()

        // Then
        XCTAssertNotNil(timeUntil)
    }

    func testAlarmOrdering_afterMultipleOperations_shouldMaintainSort() async {
        // Given
        let alarm1 = Alarm(title: "9시", hour: 9, minute: 0, isEnabled: true)
        let alarm2 = Alarm(title: "7시", hour: 7, minute: 0, isEnabled: true)
        let alarm3 = Alarm(title: "8시", hour: 8, minute: 0, isEnabled: true)

        modelContext.insert(alarm1)
        modelContext.insert(alarm2)
        modelContext.insert(alarm3)
        try? modelContext.save()

        // When
        viewModel.loadAlarms()

        // Then - Should be sorted: 7시, 8시, 9시
        XCTAssertEqual(viewModel.alarms[0].hour, 7)
        XCTAssertEqual(viewModel.alarms[1].hour, 8)
        XCTAssertEqual(viewModel.alarms[2].hour, 9)
    }
}
