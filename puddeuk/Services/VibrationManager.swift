import Foundation
import AudioToolbox
import Combine

class VibrationManager: ObservableObject {
    private var timer: Timer?
    private var isActive = false

    func start() {
        guard !isActive else { return }
        isActive = true
        vibrate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isActive else {
                timer.invalidate()
                return
            }
            self.vibrate()
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    private func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
