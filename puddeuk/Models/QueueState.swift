import Foundation
import SwiftData

/// 노티피케이션 큐의 영속적 상태를 저장하는 SwiftData 모델
///
/// 앱 재시작 후에도 큐 상태를 복원하기 위해 사용됩니다.
/// - lastSyncTimestamp: 마지막 동기화 시간
/// - scheduledIdentifiers: iOS에 스케줄된 노티피케이션 ID 목록
/// - queueVersion: 큐 버전 (향후 마이그레이션용)
@Model
final class QueueState {
    var lastSyncTimestamp: Date
    var scheduledIdentifiers: [String]
    var queueVersion: Int

    init(lastSyncTimestamp: Date = Date(), scheduledIdentifiers: [String] = [], queueVersion: Int = 1) {
        self.lastSyncTimestamp = lastSyncTimestamp
        self.scheduledIdentifiers = scheduledIdentifiers
        self.queueVersion = queueVersion
    }
}
