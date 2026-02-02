import SwiftUI

struct ToolbarButtons: View {
    let alarms: [Alarm]
    let onAddTap: () -> Void

    var body: some View {
        Button {
            onAddTap()
        } label: {
            Image(systemName: "plus")
                .font(.omyu(size: 22))
                .foregroundColor(.teal)
        }
    }
}