import Foundation
import OSLog

@MainActor
final class AlarmSystemInfo {
    static let shared = AlarmSystemInfo()

    private init() {}

    /// 시스템 정보를 상세하게 로깅
    func logSystemInfo() {
        let factory = AlarmSchedulerFactory.shared
        let system = factory.currentSystem

        Logger.alarm.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Logger.alarm.info("📱 Alarm System Information")
        Logger.alarm.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Logger.alarm.info("System: \(factory.schedulerDescription)")
        Logger.alarm.info("Type: \(system == .alarmKit ? "AlarmKit" : "Legacy")")

        if system == .alarmKit {
            Logger.alarm.info("Components: AlarmKitScheduler only")
            Logger.alarm.info("Queue Manager: ❌ Disabled")
            Logger.alarm.info("Audio Service: ❌ Disabled")
        } else {
            Logger.alarm.info("Components: AlarmScheduler + Queue + Audio")
            Logger.alarm.info("Queue Manager: ✅ Active")
            Logger.alarm.info("Audio Service: ✅ Active")
        }

        Logger.alarm.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}
