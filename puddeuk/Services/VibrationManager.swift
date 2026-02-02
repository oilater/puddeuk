import Foundation
import AudioToolbox
import Combine

class VibrationManager: ObservableObject {
    private var timer: Timer?
    private var isActive = false

    func start() {
        guard !isActive else { return }
        isActive = true
        vibratePattern()

        timer = Timer.scheduledTimer(
            withTimeInterval: AlarmConfiguration.vibrationInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self = self, self.isActive else {
                timer.invalidate()
                return
            }
            self.vibratePattern()
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    private func vibratePattern() {
        for i in 0..<AlarmConfiguration.vibrationRepeatCount {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (AlarmConfiguration.vibrationPatternDelay * Double(i))
            ) { [weak self] in
                guard let self = self, self.isActive else { return }
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}
