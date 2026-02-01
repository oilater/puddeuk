import Foundation
import SwiftUI
import SwiftData
import Combine

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var activeAlarm: Alarm?
    @Published var showAlarmView = false

    private init() {}

    func showAlarm(_ alarm: Alarm) {
        DispatchQueue.main.async {
            self.activeAlarm = alarm
            self.showAlarmView = true
        }
    }

    func dismissAlarm() {
        DispatchQueue.main.async {
            self.showAlarmView = false
            self.activeAlarm = nil
        }
    }
}
