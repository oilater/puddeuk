import SwiftUI

struct AlarmListView: View {
    let alarms: [Alarm]
    let onAlarmTap: (Alarm) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(alarms) { alarm in
                    AlarmRow(alarm: alarm) {
                        onAlarmTap(alarm)
                    }
                }
            }
            .padding()
        }
    }
}
