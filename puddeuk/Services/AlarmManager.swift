import Foundation
import SwiftUI
import SwiftData
import Combine

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var activeAlarm: Alarm?
    @Published var showAlarmView = false

    /// 알림에서 온 경우 사용 (Alarm 객체 없이)
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

    /// 알림 탭으로 앱이 열렸을 때 (Alarm 객체 없이 표시)
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
            self.activeAlarm = nil
            self.notificationTitle = nil
            self.notificationAudioFileName = nil
        }
    }
}
