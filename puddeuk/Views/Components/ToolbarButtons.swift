import SwiftUI

struct ToolbarButtons: View {
    let alarms: [Alarm]
    let onAddTap: () -> Void

    var body: some View {
        Button {
            onAddTap()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.pink)
        }
    }
}