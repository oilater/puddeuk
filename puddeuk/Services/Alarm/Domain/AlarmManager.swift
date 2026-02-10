import Foundation
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import OSLog

/// 알람 시스템의 Facade (외부 인터페이스)
///
/// **변경 사항:** God Object에서 Thin Facade로 변경
/// - 실제 로직은 AlarmChainOrchestrator, AlarmUIPresenter, AlarmAudioPlayer에 위임
/// - 기존 public API 유지 (backward compatibility)
/// - Views는 AlarmManager.shared를 통해 접근
@MainActor
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    // MARK: - Published Properties (Presenter에서 전달받음)

    @Published var showAlarmView = false
    @Published var showMissionCompleteView = false

    // MARK: - Legacy Properties (Backward Compatibility)

    /// Deprecated: AlarmContext를 사용하세요
    @Published var activeAlarm: Alarm?

    /// Deprecated: AlarmContext를 사용하세요
    @Published var notificationTitle: String?

    /// Deprecated: AlarmContext를 사용하세요
    @Published var notificationAudioFileName: String?

    // MARK: - Dependencies

    private let orchestrator = AlarmChainOrchestrator.shared
    private let presenter = AlarmUIPresenter.shared
    private let audioPlayer = AlarmAudioPlayer.shared

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Presenter의 상태를 이 클래스의 @Published 변수에 연결
        presenter.$showAlarmView
            .assign(to: &$showAlarmView)

        presenter.$showMissionCompleteView
            .assign(to: &$showMissionCompleteView)

        // Legacy: activeAlarmContext를 activeAlarm으로 변환 (backward compatibility)
        presenter.$activeAlarmContext
            .sink { [weak self] context in
                // TODO: Context에서 Alarm으로 변환하는 로직 필요
                // 현재는 notification 기반이므로 activeAlarm은 nil
                self?.notificationTitle = context?.title
                self?.notificationAudioFileName = context?.audioFileName
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API (Orchestrator에 위임)

    /// Notification에서 알람 처리
    func handleAlarmNotification(_ notification: UNNotification) {
        let context = AlarmContext(notification: notification)

        Logger.alarm.info("⏰ [AlarmManager] 알람 처리 → Orchestrator 위임")

        Task {
            await orchestrator.handleAlarmFired(context: context)
        }
    }

    /// 알람 끄기
    func dismissAlarm() {
        Task {
            await orchestrator.handleDismiss()
        }
    }

    /// 미션 완료
    func showMissionComplete() {
        Task {
            await orchestrator.handleMissionComplete()
        }
    }

    /// 미션 완료 화면 닫기
    func dismissMissionComplete() {
        presenter.dismissMissionComplete()
    }

    /// 오디오 중지
    func stopAlarmAudio() {
        audioPlayer.stop()
    }

    // MARK: - Legacy API (Backward Compatibility)

    /// Deprecated: Orchestrator 사용 권장
    func showAlarm(_ alarm: Alarm) {
        let context = AlarmContext(alarm: alarm)
        Task {
            await orchestrator.handleAlarmFired(context: context)
        }
    }

    /// Deprecated: handleAlarmNotification 사용 권장
    func showAlarmFromNotification(title: String, audioFileName: String?) {
        notificationTitle = title
        notificationAudioFileName = audioFileName
        showAlarmView = true
    }
}
