import Foundation

protocol AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]?)
}

extension AnalyticsLogging {
    func logEvent(_ name: String) {
        logEvent(name, parameters: nil)
    }
}
