import XCTest
@testable import puddeuk

final class AnalyticsManagerTests: XCTestCase {
    var sut: AnalyticsManager!
    var mockLogger: MockAnalyticsLogger!

    override func setUp() {
        super.setUp()
        mockLogger = MockAnalyticsLogger()
        sut = AnalyticsManager(logger: mockLogger)
    }

    override func tearDown() {
        sut = nil
        mockLogger = nil
        super.tearDown()
    }


    func test_logAlarmCreated_logsCorrectEvent() {
        sut.logAlarmCreated(hasCustomAudio: true, hasRepeat: false, hasSnooze: true)

        XCTAssertEqual(mockLogger.loggedEvents.count, 1)
        XCTAssertEqual(mockLogger.lastEvent?.name, "alarm_created")
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["has_custom_audio"], "true")
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["has_repeat"], "false")
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["has_snooze"], "true")
    }

    func test_logAlarmUpdated_logsCorrectEvent() {
        sut.logAlarmUpdated(hasCustomAudio: true)

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "alarm_updated"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["has_custom_audio"], "true")
    }

    func test_logAlarmDeleted_logsCorrectEvent() {
        sut.logAlarmDeleted()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "alarm_deleted"))
        XCTAssertEqual(mockLogger.loggedEvents.count, 1)
    }

    func test_logAlarmToggled_enabled_logsCorrectEvent() {
        sut.logAlarmToggled(isEnabled: true)

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "alarm_toggled"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["enabled"], "true")
    }

    func test_logAlarmToggled_disabled_logsCorrectEvent() {
        sut.logAlarmToggled(isEnabled: false)

        XCTAssertEqual(mockLogger.lastEvent?.parameters?["enabled"], "false")
    }

    func test_logAlarmDismissed_logsCorrectEvent() {
        sut.logAlarmDismissed()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "alarm_dismissed"))
    }

    func test_logAlarmSnoozed_logsCorrectEvent() {
        sut.logAlarmSnoozed(minutes: 10)

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "alarm_snoozed"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["snooze_minutes"], "10")
    }


    func test_logRecordingStarted_logsCorrectEvent() {
        sut.logRecordingStarted()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "recording_started"))
    }

    func test_logRecordingCompleted_logsCorrectEvent() {
        sut.logRecordingCompleted(duration: 15.5)

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "recording_completed"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["duration_seconds"], "15")
    }

    func test_logRecordingCanceled_logsCorrectEvent() {
        sut.logRecordingCanceled()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "recording_canceled"))
    }

    func test_logRecordingLimitReached_logsCorrectEvent() {
        sut.logRecordingLimitReached()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "recording_limit_reached"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["max_duration"], "25")
    }

    func test_logRecordingPlayed_logsCorrectEvent() {
        sut.logRecordingPlayed()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "recording_played"))
    }


    func test_logOnboardingCompleted_logsCorrectEvent() {
        sut.logOnboardingCompleted()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "onboarding_completed"))
    }

    func test_logOnboardingStepViewed_logsCorrectEvent() {
        sut.logOnboardingStepViewed(step: 3)

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "onboarding_step_viewed"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["step"], "3")
    }


    func test_logScreenViewed_logsCorrectEvent() {
        sut.logScreenViewed(screenName: "AlarmListView")

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "screen_view"))
    }


    func test_logError_logsCorrectEvent() {
        sut.logError(type: .alarmSave, message: "Failed to save")

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "error_occurred"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["error_type"], "alarm_save")
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["error_message"], "Failed to save")
    }

    func test_logAlarmSaveFailed_logsCorrectEvent() {
        sut.logAlarmSaveFailed(message: "DB error")

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "error_alarm_save_failed"))
        XCTAssertEqual(mockLogger.lastEvent?.parameters?["error_message"], "DB error")
    }

    func test_logNotificationPermissionDenied_logsCorrectEvent() {
        sut.logNotificationPermissionDenied()

        XCTAssertTrue(mockLogger.hasLogged(eventNamed: "error_notification_permission_denied"))
    }


    func test_multipleEvents_allLogged() {
        sut.logAlarmCreated(hasCustomAudio: true, hasRepeat: false, hasSnooze: false)
        sut.logRecordingStarted()
        sut.logAlarmDeleted()

        XCTAssertEqual(mockLogger.loggedEvents.count, 3)
        XCTAssertEqual(mockLogger.loggedEvents[0].name, "alarm_created")
        XCTAssertEqual(mockLogger.loggedEvents[1].name, "recording_started")
        XCTAssertEqual(mockLogger.loggedEvents[2].name, "alarm_deleted")
    }

    func test_sameEvent_loggedMultipleTimes() {
        sut.logAlarmCreated(hasCustomAudio: true, hasRepeat: false, hasSnooze: false)
        sut.logAlarmCreated(hasCustomAudio: false, hasRepeat: true, hasSnooze: true)

        XCTAssertEqual(mockLogger.count(of: "alarm_created"), 2)
    }


    func test_noEvents_emptyLog() {
        XCTAssertTrue(mockLogger.loggedEvents.isEmpty)
        XCTAssertNil(mockLogger.lastEvent)
    }

    func test_parameters_withNilValues() {
        sut.logAlarmDeleted()  // parameters: nil

        XCTAssertNotNil(mockLogger.lastEvent)
        XCTAssertNil(mockLogger.lastEvent?.parameters)
    }
}
