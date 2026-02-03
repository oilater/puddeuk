import SwiftUI

struct AlarmListView: View {
    let alarms: [Alarm]
    let timeUntilNextAlarm: String?
    let onAlarmTap: (Alarm) -> Void
    let onAlarmDelete: (Alarm) -> Void

    var body: some View {
        List {
            if let timeMessage = timeUntilNextAlarm {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.teal)
                        Text(timeMessage)
                            .font(.omyu(size: 20))
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                }
            }

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
                    .tint(.red)
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

            AlarmListView(
                alarms: mockAlarms,
                timeUntilNextAlarm: "30분 후에 알람이 울려요"
            ) { alarm in
            } onAlarmDelete: { alarm in
            }
        }
        .navigationTitle("알람")
    }
    .preferredColorScheme(.dark)
}
