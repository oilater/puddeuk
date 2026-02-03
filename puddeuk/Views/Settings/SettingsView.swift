import SwiftUI

struct SettingsView: View {
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
                            SleepModeGuideView()
                                .onAppear {
                                    AnalyticsManager.shared.logSleepModeGuideOpened()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundStyle(.teal)
                                Text("수면 모드 설정 방법")
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
                                Text("사용 후기 남기기")
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
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
