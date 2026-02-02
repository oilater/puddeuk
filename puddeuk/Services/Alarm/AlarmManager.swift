import Foundation
import SwiftUI
import SwiftData
import Combine

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var activeAlarm: Alarm?
    @Published var showAlarmView = false
    @Published var showMissionCompleteView = false

    @Published var notificationTitle: String?
    @Published var notificationAudioFileName: String?

    private init() {}

    func showAlarm(_ alarm: Alarm) {
        DispatchQueue.main.async {
            self.activeAlarm = alarm
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
            self.showAlarmView = true
        }
    }

    func showAlarmFromNotification(title: String, audioFileName: String?) {
        DispatchQueue.main.async {
            self.activeAlarm = nil
            self.notificationTitle = title
            self.notificationAudioFileName = audioFileName
            self.showAlarmView = true
        }
    }

    func dismissAlarm() {
        DispatchQueue.main.async {
            self.showAlarmView = false
            self.showMissionCompleteView = false
            self.activeAlarm = nil
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
        }
    }

    func showMissionComplete() {
        DispatchQueue.main.async {
            self.showAlarmView = false
            self.activeAlarm = nil
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
            // Small delay to ensure AlarmView dismisses first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showMissionCompleteView = true
            }
        }
    }

    func dismissMissionComplete() {
        DispatchQueue.main.async {
            self.showMissionCompleteView = false
        }
    }
}
