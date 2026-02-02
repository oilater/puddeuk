import SwiftUI

struct RecordingProgressRing: View {
    let progress: Double
    let isWarning: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isWarning ? Color.orange : Color.teal,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RecordingProgressRing(progress: 0.3, isWarning: false)
            .frame(width: 40, height: 40)

        RecordingProgressRing(progress: 0.85, isWarning: true)
            .frame(width: 40, height: 40)
    }
    .padding()
    .background(Color.black)
}
