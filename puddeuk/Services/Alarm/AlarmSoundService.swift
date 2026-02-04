import Foundation
import UserNotifications
import OSLog

final class AlarmSoundService {
    static let shared = AlarmSoundService()

    private let fileManager = FileManager.default
    private let soundsDirectory: URL

    private init() {
        soundsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
    }

    func notificationSound(for audioFileName: String?) -> UNNotificationSound {
        guard let audioFileName, !audioFileName.isEmpty else {
            return .default
        }

        if fileExists(audioFileName) {
            return UNNotificationSound(named: UNNotificationSoundName(audioFileName))
        }

        return .default
    }

    func extendedFileName(for originalFileName: String) -> String {
        let baseName = (originalFileName as NSString).deletingPathExtension
        return "\(baseName)_ext.caf"
    }

    func fileExists(_ fileName: String) -> Bool {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func fileSize(_ fileName: String) -> Int? {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int else {
            return nil
        }
        return size
    }

    func logAllSoundFiles() {
        #if DEBUG
        do {
            let files = try fileManager.contentsOfDirectory(atPath: soundsDirectory.path)
            Logger.alarm.debug("Library/Sounds: \(files.count)개 파일")
        } catch {
            Logger.alarm.error("디렉토리 읽기 실패")
        }
        #endif
    }
}
