import SwiftUI

struct DeveloperMessageView: View {
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.teal)
                        Spacer()
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 20) {
                        Text("developer.message.title")
                            .font(.omyu(size: 22))
                            .foregroundStyle(.white)

                        Text("developer.message.p1")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("developer.message.p2")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("developer.message.p3")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("developer.message.p4")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("settings.introduce")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeveloperMessageView()
    }
}
