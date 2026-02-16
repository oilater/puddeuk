import SwiftUI

struct RepeatDaySelector: View {
    @Binding var repeatDays: Set<Int>

    private let dayNames = ["일", "월", "화", "수", "목", "금", "토"]

    private var repeatText: String {
        if repeatDays.isEmpty {
            return "한번만"
        } else if repeatDays.count == 7 {
            return "매일"
        } else if repeatDays == Set([1, 2, 3, 4, 5]) {
            return "주중"
        } else if repeatDays == Set([0, 6]) {
            return "주말"
        } else {
            return repeatDays.sorted().map { dayNames[$0] }.joined(separator: ", ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(repeatText)
                    .font(.omyuHeadline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    if repeatDays.count == 7 {
                        repeatDays.removeAll()
                    } else {
                        repeatDays = Set(0..<7)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: repeatDays.count == 7 ? "checkmark.square.fill" : "square")
                            .foregroundColor(.teal)
                            .font(.system(size: 18))
                        Text("매일")
                            .font(.omyuBody)
                            .foregroundColor(.white)
                    }
                }
            }

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
                            .font(.omyu(size: 16))
                            .foregroundColor(repeatDays.contains(dayIndex) ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(repeatDays.contains(dayIndex) ? Color.teal : Color.gray.opacity(0.3))
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
