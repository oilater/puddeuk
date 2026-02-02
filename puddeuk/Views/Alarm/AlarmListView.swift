import SwiftUI

struct AlarmListView: View {
    let alarms: [Alarm]
    let onAlarmTap: (Alarm) -> Void
    let onAlarmDelete: (Alarm) -> Void

    var body: some View {
        List {
            ForEach(alarms) { alarm in
                AlarmRow(alarm: alarm) {
                    onAlarmTap(alarm)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onAlarmDelete(alarm)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onAlarmDelete(alarm)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    let mockAlarms = [
        Alarm(title: "", hour: 7, minute: 0, isEnabled: true, repeatDays: [1, 2, 3, 4, 5]),
        Alarm(title: "점심 약", hour: 12, minute: 30, isEnabled: false, repeatDays: []),
        Alarm(title: "기상 알람", hour: 8, minute: 0, isEnabled: true, repeatDays: [0, 6])
    ]

    return NavigationStack {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            AlarmListView(alarms: mockAlarms) { alarm in
            } onAlarmDelete: { alarm in
            }
        }
        .navigationTitle("알람")
    }
    .preferredColorScheme(.dark)
}
