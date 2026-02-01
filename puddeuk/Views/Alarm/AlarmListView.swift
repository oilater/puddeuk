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

#Preview {
    // 1. 프리뷰에서 보여줄 가짜 데이터 생성
    let mockAlarms = [
        Alarm(title: "", hour: 7, minute: 0, isEnabled: true, repeatDays: [1, 2, 3, 4, 5]),
        Alarm(title: "점심 약", hour: 12, minute: 30, isEnabled: false, repeatDays: []),
        Alarm(title: "기상 알람", hour: 8, minute: 0, isEnabled: true, repeatDays: [0, 6])
    ]
    
    // 2. 배경색을 다크모드로 설정해서 확인
    return NavigationStack {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()
            
            AlarmListView(alarms: mockAlarms) { alarm in
                print("\(alarm.title) 클릭됨")
            }
        }
        .navigationTitle("알람")
    }
    .preferredColorScheme(.dark)
}
