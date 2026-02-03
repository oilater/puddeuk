import SwiftUI

struct DeveloperMessageView: View {
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.teal)
                        Spacer()
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("퍼뜩과 함께해주셔서 감사합니다!")
                            .font(.omyu(size: 22))
                            .foregroundStyle(.white)

                        Text("저는 아침에 일어나는 게 너무 힘들었습니다.")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("매일 듣는 기본 알람보단 차라리 내 목소리로 시원하게 깨우면 좀 더 재밌지 않을까 해서 퍼뜩을 만들었어요.")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("사용하시면서 불편한 점이나 더하고 싶은 아이디어가 있다면 언제든 후기를 보내주세요.")
                            .font(.omyuBody)
                            .foregroundStyle(.gray)
                            .lineSpacing(6)

                        Text("퍼뜩과 함께 여러분의 하루가 더 상쾌하게 시작되길 바랄게요 ☀️")
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
        .navigationTitle("퍼뜩을 소개합니다")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeveloperMessageView()
    }
}
