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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.alarm.warning("Live Activities가 비활성화되어 있습니다")
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
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            startTime = Date()
            startUpdateTimer()
            Logger.alarm.info("Live Activity 시작")
        } catch {
            Logger.alarm.error("Live Activity 시작 실패: \(error.localizedDescription)")
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

        let elapsed = Int(Date().timeIntervalSince(startTime))
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
