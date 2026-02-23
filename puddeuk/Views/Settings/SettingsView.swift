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
                            AnnouncementsView()
                                .onAppear {
                                    AnalyticsManager.shared.logAnnouncementsViewed()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "megaphone.fill")
                                    .foregroundStyle(.teal)
                                Text("settings.announcements")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))

                        NavigationLink {
                            DeveloperMessageView()
                                .onAppear {
                                    AnalyticsManager.shared.logDeveloperMessageViewed()
                                }
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.teal)
                                Text("settings.introduce")
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
                                Text("settings.notifications")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))

                        NavigationLink {
                            LanguageSettingsView()
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(.teal)
                                Text("settings.language")
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
                                Text("settings.contact")
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
                                Text("settings.review.appstore")
                                    .font(.omyuBody)
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }

                    Section {
                        HStack {
                            Text("settings.version.label")
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
            .navigationTitle("settings.navigation.title")
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
