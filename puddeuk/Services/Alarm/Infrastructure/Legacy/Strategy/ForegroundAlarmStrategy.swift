import Foundation

final class ForegroundAlarmStrategy: AlarmPlaybackStrategy {
    private let audioPlayer: AlarmAudioPlayer
    private let vibrationService: AlarmNotificationService

    var requiresChainNotifications: Bool { false }

    init(
        audioPlayer: AlarmAudioPlayer = .shared,
        vibrationService: AlarmNotificationService = .shared
    ) {
        self.audioPlayer = audioPlayer
        self.vibrationService = vibrationService
    }

    func activate(context: AlarmContext) async {
        await MainActor.run {
            if let fileName = context.audioFileName {
                audioPlayer.play(fileName: fileName, loop: true)
            }
            vibrationService.startVibration()
        }
    }

    func deactivate() async {
        await MainActor.run {
            audioPlayer.stop()
            vibrationService.stopVibration()
        }
    }
}
