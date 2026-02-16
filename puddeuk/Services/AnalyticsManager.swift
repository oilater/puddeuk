import Foundation
import FirebaseAnalytics

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let logger: AnalyticsLogging

    private convenience init() {
        self.init(logger: FirebaseAnalyticsLogger())
    }

    init(logger: AnalyticsLogging) {
        self.logger = logger
    }

    func logAlarmCreated(hasCustomAudio: Bool, hasRepeat: Bool, hasSnooze: Bool) {
        logger.logEvent("alarm_created", parameters: [
            "has_custom_audio": hasCustomAudio,
            "has_repeat": hasRepeat,
            "has_snooze": hasSnooze
        ])
    }

    func logAlarmUpdated(hasCustomAudio: Bool) {
        logger.logEvent("alarm_updated", parameters: [
            "has_custom_audio": hasCustomAudio
        ])
    }

    func logAlarmDeleted() {
        logger.logEvent("alarm_deleted", parameters: nil)
    }

    func logAlarmToggled(isEnabled: Bool) {
        logger.logEvent("alarm_toggled", parameters: [
            "enabled": isEnabled
        ])
    }

    func logAlarmDismissed() {
        logger.logEvent("alarm_dismissed", parameters: nil)
    }

    func logAlarmSnoozed(minutes: Int) {
        logger.logEvent("alarm_snoozed", parameters: [
            "snooze_minutes": minutes
        ])
    }

    func logRecordingStarted() {
        logger.logEvent("recording_started", parameters: nil)
    }

    func logRecordingCompleted(duration: Double) {
        logger.logEvent("recording_completed", parameters: [
            "duration_seconds": Int(duration)
        ])
    }

    func logRecordingCanceled() {
        logger.logEvent("recording_canceled", parameters: nil)
    }

    func logRecordingLimitReached() {
        logger.logEvent("recording_limit_reached", parameters: [
            "max_duration": 25
        ])
    }

    func logRecordingPlayed() {
        logger.logEvent("recording_played", parameters: nil)
    }

    func logOnboardingCompleted() {
        logger.logEvent("onboarding_completed", parameters: nil)
    }

    func logOnboardingStepViewed(step: Int) {
        logger.logEvent("onboarding_step_viewed", parameters: [
            "step": step
        ])
    }

    func logDeveloperMessageViewed() {
        logger.logEvent("developer_message_viewed", parameters: nil)
    }

    func logFeedbackOpened() {
        logger.logEvent("feedback_opened", parameters: nil)
    }

    func logNotificationSettingsOpened() {
        logger.logEvent("notification_settings_opened", parameters: nil)
    }

    func logAppStoreReviewRequested() {
        logger.logEvent("app_store_review_requested", parameters: nil)
    }

    func logAppOpened() {
        logger.logEvent("app_opened", parameters: nil)
    }

    func logScreenViewed(screenName: String) {
        logger.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }

    func logError(type: ErrorType, message: String) {
        logger.logEvent("error_occurred", parameters: [
            "error_type": type.rawValue,
            "error_message": message
        ])
    }

    func logAlarmSaveFailed(message: String) {
        logger.logEvent("error_alarm_save_failed", parameters: [
            "error_message": message
        ])
    }

    func logAlarmScheduleFailed(message: String) {
        logger.logEvent("error_alarm_schedule_failed", parameters: [
            "error_message": message
        ])
    }

    func logRecordingStartFailed(message: String) {
        logger.logEvent("error_recording_start_failed", parameters: [
            "error_message": message
        ])
    }

    func logRecordingSaveFailed(message: String) {
        logger.logEvent("error_recording_save_failed", parameters: [
            "error_message": message
        ])
    }

    func logPlaybackFailed(message: String) {
        logger.logEvent("error_playback_failed", parameters: [
            "error_message": message
        ])
    }

    func logNotificationPermissionDenied() {
        logger.logEvent("error_notification_permission_denied", parameters: nil)
    }
}

enum ErrorType: String {
    case alarmSave = "alarm_save"
    case alarmSchedule = "alarm_schedule"
    case recordingStart = "recording_start"
    case recordingSave = "recording_save"
    case playback = "playback"
    case notificationPermission = "notification_permission"
    case unknown = "unknown"
}
