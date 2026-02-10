import Foundation
import ActivityKit
import OSLog

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<AlarmActivityAttributes>?
    private var updateTimer: Timer?
    private var startTime: Date?

    private init() {}

    func startAlarmActivity(alarmId: String, title: String, scheduledTime: String, audioFileName: String?) {
        let authInfo = ActivityAuthorizationInfo()
        Logger.alarm.info("🔴 Live Activity 시작 시도 - enabled: \(authInfo.areActivitiesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            Logger.alarm.warning("🔴 Live Activities NOT ENABLED!")
            return
        }

        endCurrentActivity()

        let attributes = AlarmActivityAttributes(
            alarmId: alarmId,
            title: title,
            scheduledTime: scheduledTime,
            audioFileName: audioFileName
        )

        let initialState = AlarmActivityAttributes.ContentState(
            elapsedSeconds: 0,
            isRinging: true
        )

        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            startTime = Date()
            startUpdateTimer()
            Logger.alarm.info("✅ Live Activity 시작 성공 - ID: \(activity.id)")
        } catch {
            Logger.alarm.error("❌ Live Activity 시작 실패: \(error.localizedDescription)")
        }
    }

    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }
    }

    private func updateElapsedTime() {
        guard let startTime = startTime else { return }

        let timeInterval = Date().timeIntervalSince(startTime)
        guard timeInterval.isFinite else {
            Logger.alarm.error("❌ Invalid time interval: \(timeInterval)")
            return
        }

        let elapsed = Int(timeInterval)
        let newState = AlarmActivityAttributes.ContentState(
            elapsedSeconds: elapsed,
            isRinging: true
        )

        Task {
            await currentActivity?.update(
                ActivityContent(state: newState, staleDate: nil)
            )
        }
    }

    func endCurrentActivity() {
        updateTimer?.invalidate()
        updateTimer = nil
        startTime = nil

        guard let activity = currentActivity else { return }

        let finalState = AlarmActivityAttributes.ContentState(
            elapsedSeconds: 0,
            isRinging: false
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            Logger.alarm.info("Live Activity 종료")
        }

        currentActivity = nil
    }
}
