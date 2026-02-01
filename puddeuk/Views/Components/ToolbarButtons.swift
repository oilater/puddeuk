import SwiftUI

struct ToolbarButtons: View {
    let alarms: [Alarm]
    let onAddTap: () -> Void

    var body: some View {
        HStack {
            #if DEBUG
            Button {
                if let firstAlarm = alarms.first {
                    AlarmManager.shared.showAlarm(firstAlarm)
                } else {
                    let testAlarm = Alarm(title: "테스트 알람", hour: 0, minute: 0)
                    AlarmManager.shared.showAlarm(testAlarm)
                }
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            #endif

            Button {
                onAddTap()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.pink)
            }
        }
    }
}
