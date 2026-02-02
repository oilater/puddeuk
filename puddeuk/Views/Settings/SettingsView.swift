import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                List {
                    Section {
                        NavigationLink {
                            FeedbackView()
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(.blue)
                                Text("사용후기 남기기")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }

                    Section {
                        HStack {
                            Text("버전")
                                .font(.omyuBody)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("1.0.0")
                                .font(.omyuBody)
                                .foregroundStyle(.gray)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
