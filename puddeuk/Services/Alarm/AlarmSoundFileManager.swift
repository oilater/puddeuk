import Foundation
import OSLog

/// Manages alarm sound file operations
/// Handles copying audio files from Documents to Library/Sounds/ directory
final class AlarmSoundFileManager: Sendable {
    static let shared = AlarmSoundFileManager()

    private nonisolated(unsafe) let fileManager = FileManager.default

    private init() {}

    /// Prepare sound file for AlarmKit
    /// - Parameter fileName: Optional audio file name
    /// - Returns: File name if successfully prepared, nil otherwise
    /// - Throws: File system errors
    func prepareSoundFile(_ fileName: String?) async throws -> String? {
        guard let fileName = fileName else {
            return nil
        }

        let soundsURL = try getSoundsDirectory()
        let destURL = soundsURL.appendingPathComponent(fileName)

        // Check if file already exists in Library/Sounds/
        if fileManager.fileExists(atPath: destURL.path) {
            return fileName
        }

        // Try to copy from Documents directory
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

    // MARK: - Private Helpers

    /// Get Library/Sounds/ directory URL, creating it if needed
    private func getSoundsDirectory() throws -> URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appendingPathComponent("Sounds")

        try fileManager.createDirectory(at: soundsURL, withIntermediateDirectories: true)

        return soundsURL
    }

    /// Get Documents directory URL
    private func getDocumentsDirectory() throws -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
