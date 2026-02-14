import Foundation
import Combine
import FirebaseAnalytics

final class FirebaseAnalyticsLogger: AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)

        #if DEBUG
        print("[Analytics] Event logged: \(name)")
        if let params = parameters {
            print("  Parameters: \(params)")
        }
        #endif
    }
}
