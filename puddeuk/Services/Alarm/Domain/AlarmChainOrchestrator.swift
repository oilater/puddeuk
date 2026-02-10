import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
final class AlarmChainOrchestrator: ObservableObject {
    static let shared = AlarmChainOrchestrator()

    enum AppState {
        case foreground
        case background
    }


    private let gateway: NotificationGatewayProtocol
    private let uiPresenter: AlarmUIPresenter
    private let liveActivityManager: LiveActivityManager


    private var currentStrategy: AlarmPlaybackStrategy?
    private var currentContext: AlarmContext?
    private var appState: AppState = .foreground

    private lazy var foregroundStrategy = ForegroundAlarmStrategy()
    private lazy var backgroundStrategy: AlarmPlaybackStrategy = BackgroundChainStrategy(gateway: gateway)


    init(
        gateway: NotificationGatewayProtocol = NotificationGateway.shared,
        uiPresenter: AlarmUIPresenter = .shared,
        liveActivityManager: LiveActivityManager = .shared
    ) {
        self.gateway = gateway
        self.uiPresenter = uiPresenter
        self.liveActivityManager = liveActivityManager
    }


    func handleAlarmFired(context: AlarmContext, isAppActive: Bool? = nil) async {
        // 중복 알람 무시 (이미 같은 알람 처리 중)
        if currentContext?.alarmId == context.alarmId {
            Logger.alarm.info("⏭️ [Orchestrator] 이미 처리 중인 알람 - 무시: \(context.alarmId)")
            return
        }

        Logger.alarm.info("🎯 [Orchestrator] 알람 발화: \(context.title)")

        currentContext = context

        // 앱 상태 확인 (명시적 전달 또는 UIApplication으로 확인)
        if let isActive = isAppActive {
            appState = isActive ? .foreground : .background
        } else {
            appState = UIApplication.shared.applicationState == .active ? .foreground : .background
        }

        // 전략 선택 및 활성화
        let strategy = selectStrategy()
        currentStrategy = strategy

        // 포그라운드 전략이면 혹시 모를 백그라운드 체인 취소
        if appState == .foreground {
            await cancelPendingChains(for: context.alarmId)
        }

        await strategy.activate(context: context)

        // UI 표시
        uiPresenter.presentAlarm(context: context)

        // Live Activity 시작
        startLiveActivity(context: context)

        Logger.alarm.info("✅ [Orchestrator] 알람 시작 완료 - 전략: \(self.appState == .foreground ? "Foreground" : "Background")")
    }

    func isAlarmActive(_ alarmId: String) -> Bool {
        return currentContext?.alarmId == alarmId
    }

    func handleDismiss() async {
        Logger.alarm.info("🔕 [Orchestrator] 알람 종료 (dismiss)")
        await cleanup()
        uiPresenter.dismiss()
    }

    func handleMissionComplete() async {
        Logger.alarm.info("✅ [Orchestrator] 미션 완료")
        await cleanup()
        uiPresenter.transitionToMissionComplete()
    }

    func handleSnooze(minutes: Int, audioFileName: String?) async {
        Logger.alarm.info("😴 [Orchestrator] 스누즈: \(minutes)분")
        await cleanup()
        uiPresenter.dismiss()

        // 스누즈 알람 스케줄
        do {
            try await AlarmNotificationManager.shared.scheduleSnooze(
                minutes: minutes,
                audioFileName: audioFileName
            )
        } catch {
            Logger.alarm.error("❌ [Orchestrator] 스누즈 스케줄 실패: \(error.localizedDescription)")
        }
    }


    func appDidEnterForeground() async {
        let previousState = appState
        appState = .foreground

        guard let context = currentContext else {
            Logger.alarm.debug("ℹ️ [Orchestrator] 포그라운드 전환 - 활성 알람 없음")
            return
        }

        Logger.alarm.info("🔄 [Orchestrator] 포그라운드 전환 (이전: \(previousState == .background ? "Background" : "Foreground"))")

        // 체인 노티는 무조건 취소 (이전 상태 무관)
        await cancelPendingChains(for: context.alarmId)

        // 백그라운드에서 왔으면 전략 전환
        if previousState == .background {
            await currentStrategy?.deactivate()

            let newStrategy = foregroundStrategy
            currentStrategy = newStrategy
            await newStrategy.activate(context: context)
        }
    }

    func appDidEnterBackground() async {
        let previousState = appState
        appState = .background

        guard let context = currentContext, previousState == .foreground else {
            Logger.alarm.debug("ℹ️ [Orchestrator] 백그라운드 전환 - 활성 알람 없음")
            return
        }

        Logger.alarm.info("🔄 [Orchestrator] 백그라운드 전환 - 체인 스케줄")

        // Foreground → Background: 앱 내 오디오 중지, 체인 스케줄
        await currentStrategy?.deactivate()

        let newStrategy = backgroundStrategy
        currentStrategy = newStrategy
        await newStrategy.activate(context: context)
    }


    private func selectStrategy() -> AlarmPlaybackStrategy {
        switch appState {
        case .foreground:
            return foregroundStrategy
        case .background:
            return backgroundStrategy
        }
    }

    private func cleanup() async {
        // 전략 비활성화
        await currentStrategy?.deactivate()

        // 체인 노티피케이션 취소
        if let alarmId = currentContext?.alarmId {
            await cancelPendingChains(for: alarmId)
        }

        // Live Activity 종료
        liveActivityManager.endCurrentActivity()

        // 상태 초기화
        currentContext = nil
        currentStrategy = nil

        Logger.alarm.debug("🧹 [Orchestrator] 정리 완료")
    }

    private func cancelPendingChains(for alarmId: String) async {
        let pending = await gateway.pendingRequests()

        // alarmId로 시작하는 모든 체인 노티피케이션 찾기
        let chainIds = pending
            .map { $0.identifier }
            .filter { $0.hasPrefix(alarmId) && $0.contains("-chain-") }

        guard !chainIds.isEmpty else {
            Logger.alarm.debug("🗑️ [Orchestrator] 취소할 체인 없음: \(alarmId)")
            return
        }

        gateway.removePending(identifiers: chainIds)
        Logger.alarm.info("🗑️ [Orchestrator] 체인 취소 완료: \(alarmId) - \(chainIds.count)개")
    }

    private func startLiveActivity(context: AlarmContext) {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        let timeString = formatter.string(from: context.scheduledTime)

        liveActivityManager.startAlarmActivity(
            alarmId: context.alarmId,
            title: context.title,
            scheduledTime: timeString,
            audioFileName: context.audioFileName ?? ""
        )
    }
}
