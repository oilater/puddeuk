import SwiftUI

struct EmptyAlarmView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 64))
                .foregroundColor(.pink.opacity(0.6))

            Text("알람이 없어요")
                .font(.title2)
                .foregroundColor(.white)

            Text("+ 버튼을 눌러 알람을 추가해보세요")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
