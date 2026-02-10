import Foundation
import UserNotifications
import OSLog

protocol NotificationGatewayProtocol: Sendable {
    func addRequest(_ request: UNNotificationRequest) async throws
    func removePending(identifiers: [String])
    func removeAllPending()
    func pendingRequests() async -> [UNNotificationRequest]
    func deliveredNotifications() async -> [UNNotification]
    func removeDelivered(identifiers: [String])
}

final class NotificationGateway: NotificationGatewayProtocol, @unchecked Sendable {
    static let shared = NotificationGateway()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func addRequest(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
        await logRequest(request)
    }

    func removePending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        Task { @MainActor in
            Logger.alarm.debug("🗑️ [Gateway] Pending 제거: \(identifiers.count)개")
        }
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
        Task { @MainActor in
            Logger.alarm.info("🗑️ [Gateway] 모든 Pending 제거")
        }
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }

    func deliveredNotifications() async -> [UNNotification] {
        return await center.deliveredNotifications()
    }

    func removeDelivered(identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        Task { @MainActor in
            Logger.alarm.debug("🗑️ [Gateway] Delivered 제거: \(identifiers.count)개")
        }
    }


    private func logRequest(_ request: UNNotificationRequest) async {
        await MainActor.run {
            Logger.alarm.debug("📝 [Gateway] 노티피케이션 추가: \(request.identifier)")
        }
    }
}
