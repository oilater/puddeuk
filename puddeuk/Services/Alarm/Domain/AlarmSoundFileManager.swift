import Foundation
import UserNotifications
import OSLog

final class AlarmSoundFileManager: Sendable {
    static let shared = AlarmSoundFileManager()

    private nonisolated(unsafe) let fileManager = FileManager.default
    private let soundsDirectory: URL

    private init() {
        soundsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
    }

    func prepareSoundFile(_ fileName: String?) async throws -> String? {
        guard let fileName = fileName else {
            return nil
        }

        let soundsURL = try getSoundsDirectory()
        let destURL = soundsURL.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destURL.path) {
            return fileName
        }

        let sourceURL = try getDocumentsDirectory().appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            Task { @MainActor in
                Logger.alarm.warning("[AlarmSoundFileManager] 사운드 파일 없음: \(fileName)")
            }
            return nil
        }

        try fileManager.copyItem(at: sourceURL, to: destURL)
        Task { @MainActor in
            Logger.alarm.info("[AlarmSoundFileManager] 사운드 파일 복사 완료: \(fileName)")
        }

        return fileName
    }


    private func getSoundsDirectory() throws -> URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appendingPathComponent("Sounds")

        try fileManager.createDirectory(at: soundsURL, withIntermediateDirectories: true)

        return soundsURL
    }

    private func getDocumentsDirectory() throws -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
            Task { @MainActor in
                Logger.alarm.debug("Library/Sounds: \(files.count)개 파일")
            }
        } catch {
            Task { @MainActor in
                Logger.alarm.error("디렉토리 읽기 실패")
            }
        }
        #endif
    }
}
