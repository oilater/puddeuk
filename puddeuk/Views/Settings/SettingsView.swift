import SwiftUI
import AlarmKit

struct SettingsView: View {
    @State private var testAlarmScheduled = false

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

                    #if DEBUG
                    Section(header: Text("🔧 디버그 (AlarmKit)").foregroundStyle(.teal)) {
                        Button {
                            testAlarmKitDirect()
                        } label: {
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundStyle(.orange)
                                Text("AlarmKit 직접 테스트 (1분 후)")
                                    .font(.omyuBody)
                                Spacer()
                                if testAlarmScheduled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .foregroundStyle(.white)
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }
                    #endif

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

    private func testAlarmKitDirect() {
        Task {
            let alarmManager = AlarmKit.AlarmManager.shared

            guard alarmManager.authorizationState == .authorized else {
                return
            }

            // 1분 후 알람 설정
            let fireDate = Date().addingTimeInterval(60)
            let schedule = AlarmKit.Alarm.Schedule.fixed(fireDate)

            // Alert 구성
            let alert = AlarmPresentation.Alert(
                title: "🔧 직접 테스트",
                stopButton: AlarmButton(
                    text: "끄기",
                    textColor: .white,
                    systemImageName: "stop.circle"
                )
            )

            let presentation = AlarmPresentation(alert: alert)

            let attributes = AlarmKit.AlarmAttributes<PuddeukAlarmMetadata>(
                presentation: presentation,
                metadata: PuddeukAlarmMetadata(),
                tintColor: .orange
            )

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                schedule: schedule,
                attributes: attributes
            )

            do {
                _ = try await alarmManager.schedule(id: UUID(), configuration: configuration)
                await MainActor.run {
                    testAlarmScheduled = true
                }

                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    testAlarmScheduled = false
                }
            } catch {
                await MainActor.run {
                    testAlarmScheduled = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
