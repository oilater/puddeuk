import Foundation
import SwiftData
import OSLog

final class AlarmSchedulerFactory {
    static let shared = AlarmSchedulerFactory()

    // MARK: - System Type

    enum SystemType {
        case alarmKit   // iOS 26+
        case legacy     // iOS 17-25
    }

    private init() {}

    // MARK: - System Detection

    /// 현재 시스템 타입 판별
    var currentSystem: SystemType {
        if #available(iOS 26, *) {
            #if canImport(AlarmKit)
            return .alarmKit
            #else
            return .legacy
            #endif
        } else {
            return .legacy
        }
    }

    /// Legacy 시스템 여부 (편의 프로퍼티)
    var isLegacySystem: Bool {
        currentSystem == .legacy
    }

    /// AlarmKit 사용 가능 여부 (편의 프로퍼티)
    var isAlarmKitAvailable: Bool {
        currentSystem == .alarmKit
    }

    /// 현재 시스템 설명
    var schedulerDescription: String {
        switch currentSystem {
        case .alarmKit:
            return "AlarmKit (iOS 26+)"
        case .legacy:
            return "UNUserNotificationCenter (iOS 17-25)"
        }
    }

    // MARK: - Scheduler Factory

    /// 현재 시스템에 맞는 스케줄러 생성
    func createScheduler() -> any AlarmScheduling {
        switch currentSystem {
        case .alarmKit:
            return createAlarmKitScheduler()
        case .legacy:
            return createLegacyScheduler()
        }
    }

    // MARK: - Private Factory Methods

    private func createAlarmKitScheduler() -> any AlarmScheduling {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            Logger.alarm.info("✅ [Factory] AlarmKit 시스템 초기화 (iOS 26+)")
            return AlarmKitScheduler()
        }
        #endif
        Logger.alarm.error("❌ [Factory] AlarmKit 초기화 실패 - iOS 버전 부족")
        fatalError("AlarmKit not available")
    }

    private func createLegacyScheduler() -> any AlarmScheduling {
        Logger.alarm.info("✅ [Factory] Legacy 시스템 초기화")
        return AlarmScheduler.shared
    }
}
