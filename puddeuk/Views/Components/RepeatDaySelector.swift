import SwiftUI

struct RepeatDaySelector: View {
    @Binding var repeatDays: Set<Int>

    private let dayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("반복")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    Button {
                        if repeatDays.contains(dayIndex) {
                            repeatDays.remove(dayIndex)
                        } else {
                            repeatDays.insert(dayIndex)
                        }
                    } label: {
                        Text(dayNames[dayIndex])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(repeatDays.contains(dayIndex) ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(repeatDays.contains(dayIndex) ? Color.pink : Color.gray.opacity(0.3))
                            .cornerRadius(22)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

#Preview {
    RepeatDaySelector(repeatDays: .constant([0, 6]))
        .preferredColorScheme(.dark)
}
