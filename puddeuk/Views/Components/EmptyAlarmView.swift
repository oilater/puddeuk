import SwiftUI

struct EmptyAlarmView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.fill")
                .font(.omyu(size: 64))
                .foregroundColor(.teal.opacity(0.6))

            Text("알람이 없어요")
                .font(.omyuTitle2)
                .foregroundColor(.white)

            Text("+ 버튼을 눌러 알람을 추가해보세요")
                .font(.omyuSubheadline)
                .foregroundColor(.gray)
        }
    }
}
