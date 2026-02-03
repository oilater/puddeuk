import Foundation
import FirebaseAnalytics

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {}

    // MARK: - Alarm Events

    func logAlarmCreated(hasCustomAudio: Bool, hasRepeat: Bool, hasSnooze: Bool) {
        Analytics.logEvent("alarm_created", parameters: [
            "has_custom_audio": hasCustomAudio,
            "has_repeat": hasRepeat,
            "has_snooze": hasSnooze
        ])
    }

    func logAlarmUpdated(hasCustomAudio: Bool) {
        Analytics.logEvent("alarm_updated", parameters: [
            "has_custom_audio": hasCustomAudio
        ])
    }

    func logAlarmDeleted() {
        Analytics.logEvent("alarm_deleted", parameters: nil)
    }

    func logAlarmToggled(isEnabled: Bool) {
        Analytics.logEvent("alarm_toggled", parameters: [
            "enabled": isEnabled
        ])
    }

    func logAlarmDismissed() {
        Analytics.logEvent("alarm_dismissed", parameters: nil)
    }

    func logAlarmSnoozed(minutes: Int) {
        Analytics.logEvent("alarm_snoozed", parameters: [
            "snooze_minutes": minutes
        ])
    }

    // MARK: - Recording Events

    func logRecordingStarted() {
        Analytics.logEvent("recording_started", parameters: nil)
    }

    func logRecordingCompleted(duration: Double) {
        Analytics.logEvent("recording_completed", parameters: [
            "duration_seconds": Int(duration)
        ])
    }

    func logRecordingCanceled() {
        Analytics.logEvent("recording_canceled", parameters: nil)
    }

    func logRecordingLimitReached() {
        Analytics.logEvent("recording_limit_reached", parameters: [
            "max_duration": 25
        ])
    }

    func logRecordingPlayed() {
        Analytics.logEvent("recording_played", parameters: nil)
    }

    // MARK: - Onboarding Events

    func logOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    func logOnboardingStepViewed(step: Int) {
        Analytics.logEvent("onboarding_step_viewed", parameters: [
            "step": step
        ])
    }

    // MARK: - Settings Events

    func logDeveloperMessageViewed() {
        Analytics.logEvent("developer_message_viewed", parameters: nil)
    }

    func logFeedbackOpened() {
        Analytics.logEvent("feedback_opened", parameters: nil)
    }

    func logNotificationSettingsOpened() {
        Analytics.logEvent("notification_settings_opened", parameters: nil)
    }

    func logSleepModeGuideOpened() {
        Analytics.logEvent("sleep_mode_guide_opened", parameters: nil)
    }

    // MARK: - App Lifecycle Events

    func logAppOpened() {
        Analytics.logEvent("app_opened", parameters: nil)
    }

    func logScreenViewed(screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }

    // MARK: - Error Events

    func logError(type: ErrorType, message: String) {
        Analytics.logEvent("error_occurred", parameters: [
            "error_type": type.rawValue,
            "error_message": message
        ])
    }

    func logAlarmSaveFailed(message: String) {
        Analytics.logEvent("error_alarm_save_failed", parameters: [
            "error_message": message
        ])
    }

    func logAlarmScheduleFailed(message: String) {
        Analytics.logEvent("error_alarm_schedule_failed", parameters: [
            "error_message": message
        ])
    }

    func logRecordingStartFailed(message: String) {
        Analytics.logEvent("error_recording_start_failed", parameters: [
            "error_message": message
        ])
    }

    func logRecordingSaveFailed(message: String) {
        Analytics.logEvent("error_recording_save_failed", parameters: [
            "error_message": message
        ])
    }

    func logPlaybackFailed(message: String) {
        Analytics.logEvent("error_playback_failed", parameters: [
            "error_message": message
        ])
    }

    func logNotificationPermissionDenied() {
        Analytics.logEvent("error_notification_permission_denied", parameters: nil)
    }
}

// MARK: - Error Types

enum ErrorType: String {
    case alarmSave = "alarm_save"
    case alarmSchedule = "alarm_schedule"
    case recordingStart = "recording_start"
    case recordingSave = "recording_save"
    case playback = "playback"
    case notificationPermission = "notification_permission"
    case unknown = "unknown"
}
