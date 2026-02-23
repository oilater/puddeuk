import SwiftUI

struct EmptyAlarmView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.fill")
                .font(.omyu(size: 64))
                .foregroundColor(.teal.opacity(0.6))

            Text("alarm.empty.title")
                .font(.omyuTitle2)
                .foregroundColor(.white)

            Text("alarm.empty.subtitle")
                .font(.omyuSubheadline)
                .foregroundColor(.gray)
        }
    }
}
