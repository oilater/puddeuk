import Foundation
import UserNotifications
import SwiftData

class AlarmNotificationManager {
    static let shared = AlarmNotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 알림 권한 허용됨")
                self.checkAuthorizationStatus()
            } else {
                print("❌ 알림 권한 거부됨: \(error?.localizedDescription ?? "")")
                self.checkAuthorizationStatus()
            }
        }
    }

    func scheduleAlarm(_ alarm: Alarm) {
        guard alarm.isEnabled else {
            cancelAlarm(alarm)
            return
        }

        if alarm.repeatDays.isEmpty {
            scheduleSingleAlarm(alarm)
        } else {
            for day in alarm.repeatDays {
                scheduleRepeatingAlarm(alarm, weekday: day)
            }
        }
    }

    private func scheduleSingleAlarm(_ alarm: Alarm) {
        let content = createNotificationContent(for: alarm)
        guard let triggerDate = calculateNextAlarmDate(for: alarm) else {
            print("❌ 알람 시간 계산 실패")
            return
        }

        logAlarmSchedule(alarm: alarm, triggerDate: triggerDate)

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ 알람 스케줄링 실패: \(error)")
            } else {
                print("✅ 알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString)")
                self?.printPendingNotifications()
            }
        }
    }

    private func scheduleRepeatingAlarm(_ alarm: Alarm, weekday: Int) {
        let content = createNotificationContent(for: alarm)
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday + 1
        dateComponents.hour = alarm.hour
        dateComponents.minute = alarm.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "\(alarm.id.uuidString)-\(weekday)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 반복 알람 스케줄링 실패: \(error)")
            } else {
                print("✅ 반복 알람 스케줄링 성공: \(alarm.title) - \(alarm.timeString) (요일: \(weekday))")
            }
        }
    }

    private func createNotificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "알람" : alarm.title
        content.body = "알람 시간입니다. 탭하여 끄기"

        if let audioFileName = alarm.audioFileName, !audioFileName.isEmpty {
            let extendedFileName = getExtendedAudioFileName(for: audioFileName)
            let soundsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Sounds")
            let extendedURL = soundsDir.appendingPathComponent(extendedFileName)

            if FileManager.default.fileExists(atPath: extendedURL.path) {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(extendedFileName))
                print("🔊 노티피케이션 사운드: \(extendedFileName)")
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(audioFileName))
                print("🔊 노티피케이션 사운드 (원본): \(audioFileName)")
            }
        } else {
            content.sound = .default
        }

        content.categoryIdentifier = "ALARM"
        content.interruptionLevel = .timeSensitive

        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "audioFileName": alarm.audioFileName ?? "",
            "title": alarm.title.isEmpty ? "알람" : alarm.title
        ]
        return content
    }

    private func getExtendedAudioFileName(for originalFileName: String) -> String {
        let baseName = (originalFileName as NSString).deletingPathExtension
        return baseName + "_extended.caf"
    }

    private func calculateNextAlarmDate(for alarm: Alarm) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        var components = DateComponents()
        components.year = calendar.component(.year, from: now)
        components.month = calendar.component(.month, from: now)
        components.day = calendar.component(.day, from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0

        var triggerDate = calendar.date(from: components)

        if let date = triggerDate, date <= now {
            components.day = (components.day ?? 0) + 1
            triggerDate = calendar.date(from: components)
        }

        return triggerDate
    }

    private func logAlarmSchedule(alarm: Alarm, triggerDate: Date) {
        let timeUntilAlarm = triggerDate.timeIntervalSince(Date())
        print("⏰ 알람 예약 시간: \(triggerDate)")
        print("   현재 시간: \(Date())")
        print("   남은 시간: \(Int(timeUntilAlarm / 60))분 \(Int(timeUntilAlarm.truncatingRemainder(dividingBy: 60)))초")
    }

    func cancelAlarm(_ alarm: Alarm) {
        let center = UNUserNotificationCenter.current()

        if alarm.repeatDays.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        } else {
            var identifiers: [String] = []
            for day in alarm.repeatDays {
                identifiers.append("\(alarm.id.uuidString)-\(day)")
            }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        print("알람 취소됨: \(alarm.title)")
    }

    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 현재 스케줄된 알림 개수: \(requests.count)")
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let dateComponents = trigger.dateComponents
                    let calendar = Calendar.current
                    if let date = calendar.date(from: dateComponents) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        print("   - \(request.content.title): \(formatter.string(from: date))")
                    } else {
                        print("   - \(request.content.title): \(dateComponents.hour ?? 0):\(String(format: "%02d", dateComponents.minute ?? 0))")
                    }
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    print("   - \(request.content.title): \(trigger.timeInterval)초 후")
                }
            }
        }
    }

    func sendTestNotification(title: String = "테스트 알람", body: String = "알람 테스트입니다") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 테스트 알림 실패: \(error)")
            } else {
                print("✅ 테스트 알림 전송 성공 (1초 후)")
            }
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 알림 권한 상태: \(settings.authorizationStatus.rawValue)")
            print("   - 알림 허용: \(settings.authorizationStatus == .authorized)")
            print("   - 알림 스타일: \(settings.alertSetting.rawValue)")
            print("   - 사운드 허용: \(settings.soundSetting.rawValue)")
        }
    }

    func checkPendingAlarm(modelContext: ModelContext) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                for notification in notifications {
                    guard let alarmIdString = notification.request.content.userInfo["alarmId"] as? String,
                          let alarmId = UUID(uuidString: alarmIdString) else {
                        continue
                    }

                    let descriptor = FetchDescriptor<Alarm>(
                        predicate: #Predicate { $0.id == alarmId }
                    )

                    do {
                        let foundAlarms = try modelContext.fetch(descriptor)
                        if let alarm = foundAlarms.first, alarm.isEnabled {
                            AlarmManager.shared.showAlarm(alarm)
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                            break
                        }
                    } catch {
                        print("❌ 알람 찾기 실패: \(error)")
                    }
                }
            }
        }
    }
}
