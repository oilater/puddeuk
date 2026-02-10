import Foundation
import AudioToolbox
import Combine

final class AlarmNotificationService: ObservableObject {

    static let shared = AlarmNotificationService()

    @Published var isAlarmPlaying = false

    private(set) var currentAlarmId: String?

    private var vibrationTimer: Timer?
    private var isVibrationActive = false

    private init() {}

    func startVibration() {
        guard !isVibrationActive else { return }
        isVibrationActive = true
        vibratePattern()

        vibrationTimer = Timer.scheduledTimer(
            withTimeInterval: AlarmConfiguration.vibrationInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self = self, self.isVibrationActive else {
                timer.invalidate()
                return
            }
            self.vibratePattern()
        }
    }

    func stopVibration() {
        isVibrationActive = false
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    private func vibratePattern() {
        for i in 0..<AlarmConfiguration.vibrationRepeatCount {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (AlarmConfiguration.vibrationPatternDelay * Double(i))
            ) { [weak self] in
                guard let self = self, self.isVibrationActive else { return }
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}
