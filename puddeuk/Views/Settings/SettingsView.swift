import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

                List {
                    Section {
                        NavigationLink {
                            DeveloperMessageView()
                                .onAppear {
                                    AnalyticsManager.shared.logDeveloperMessageViewed()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.teal)
                                Text("퍼뜩을 소개합니다")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }

                    Section {
                        NavigationLink {
                            NotificationSettingsView()
                                .onAppear {
                                    AnalyticsManager.shared.logNotificationSettingsOpened()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(.teal)
                                Text("알림 설정")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))

                        NavigationLink {
                            FeedbackView()
                                .onAppear {
                                    AnalyticsManager.shared.logFeedbackOpened()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(.teal)
                                Text("문의하기")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))

                        Button {
                            requestAppStoreReview()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("앱스토어 리뷰 남기기")
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
                            Text(appVersion)
                                .font(.omyuBody)
                                .foregroundStyle(.gray)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func requestAppStoreReview() {
        AnalyticsManager.shared.logAppStoreReviewRequested()
        requestReview()
    }
}

#Preview {
    SettingsView()
}
