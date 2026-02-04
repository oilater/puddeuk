import Foundation
@testable import puddeuk

final class MockAnalyticsLogger: AnalyticsLogging {
    private(set) var loggedEvents: [LoggedEvent] = []

    struct LoggedEvent: Equatable {
        let name: String
        let parameters: [String: String]?

        init(name: String, parameters: [String: Any]?) {
            self.name = name
            self.parameters = parameters?.mapValues { "\($0)" }
        }
    }

    func logEvent(_ name: String, parameters: [String: Any]?) {
        let event = LoggedEvent(name: name, parameters: parameters)
        loggedEvents.append(event)
    }

    func hasLogged(eventNamed name: String) -> Bool {
        return loggedEvents.contains { $0.name == name }
    }

    func count(of eventName: String) -> Int {
        return loggedEvents.filter { $0.name == eventName }.count
    }

    var lastEvent: LoggedEvent? {
        return loggedEvents.last
    }

    func clear() {
        loggedEvents.removeAll()
    }
}
