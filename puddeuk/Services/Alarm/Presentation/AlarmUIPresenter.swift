import Foundation
import SwiftUI
import Combine

@MainActor
final class AlarmUIPresenter: ObservableObject {
    static let shared = AlarmUIPresenter()

    @Published var activeAlarmContext: AlarmContext?
    @Published var showAlarmView = false
    @Published var showMissionCompleteView = false

    private init() {}


    func presentAlarm(context: AlarmContext) {
        self.activeAlarmContext = context
        self.showAlarmView = true
        self.showMissionCompleteView = false
    }

    func dismiss() {
        self.showAlarmView = false
        self.showMissionCompleteView = false
        self.activeAlarmContext = nil
    }

    func transitionToMissionComplete() {
        self.showAlarmView = false
        self.activeAlarmContext = nil

        // 약간의 딜레이 후 미션 완료 화면 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showMissionCompleteView = true
        }
    }

    func dismissMissionComplete() {
        self.showMissionCompleteView = false
    }
}
