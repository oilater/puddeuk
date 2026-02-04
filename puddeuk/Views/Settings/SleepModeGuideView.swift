import SwiftUI

struct SleepModeGuideView: View {
    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.omyu(size: 80))
                            .foregroundColor(.teal)

                        Text("수면 모드 설정")
                            .font(.omyu(size: 28))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.teal)
                            Text("앱이 꺼져 있어도 괜찮아요!")
                                .font(.omyuHeadline)
                                .foregroundColor(.white)
                        }

                        Text("퍼뜩은 앱을 종료하거나 백그라운드 상태여도 설정한 시간에 알람이 정확히 울려요. 하지만 수면 모드를 사용한다면 아래 설정이 필요해요.")
                            .font(.omyuBody)
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(Color.teal.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 20) {
                        Text("설정 방법")
                            .font(.omyuHeadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        VStack(spacing: 16) {
                            GuideStepView(
                                number: 1,
                                icon: "gearshape.fill",
                                title: "설정 앱 열기",
                                description: "아이폰 설정 앱을 열어주세요"
                            )

                            GuideStepView(
                                number: 2,
                                icon: "moon.fill",
                                title: "집중 모드 선택",
                                description: "설정 > 집중 모드를 탭하세요"
                            )

                            GuideStepView(
                                number: 3,
                                icon: "bed.double.fill",
                                title: "수면 선택",
                                description: "집중 모드 목록에서 '수면'을 탭하세요"
                            )

                            GuideStepView(
                                number: 4,
                                icon: "app.badge.checkmark.fill",
                                title: "퍼뜩 허용",
                                description: "앱 > 퍼뜩을 찾아서 허용해주세요"
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.orange)
                            Text("무음모드도 확인하세요!")
                                .font(.omyuHeadline)
                                .foregroundColor(.white)
                        }

                        Text("무음모드가 켜져 있으면 알람 소리가 나지 않아요. 알람이 울릴 시간에는 무음모드를 꼭 풀어주세요.")
                            .font(.omyuBody)
                            .foregroundColor(.orange)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("수면 모드 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideStepView: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.teal)
                    .frame(width: 36, height: 36)

                Text("\(number)")
                    .font(.omyuHeadline)
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.teal)
                        .font(.omyuBody)

                    Text(title)
                        .font(.omyuHeadline)
                        .foregroundColor(.white)
                }

                Text(description)
                    .font(.omyuBody)
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.18, green: 0.18, blue: 0.2))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        SleepModeGuideView()
    }
}
