import Foundation
import UserNotifications

/// 알람 사운드 파일 관리 서비스
final class AlarmSoundService {
    static let shared = AlarmSoundService()

    private let fileManager = FileManager.default
    private let soundsDirectory: URL

    private init() {
        soundsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
    }

    /// 알람에 맞는 UNNotificationSound 반환
    func notificationSound(for audioFileName: String?) -> UNNotificationSound {
        guard let audioFileName, !audioFileName.isEmpty else {
            return .default
        }

        let extendedFileName = extendedFileName(for: audioFileName)

        if fileExists(extendedFileName) {
            return UNNotificationSound(named: UNNotificationSoundName(extendedFileName))
        }

        if fileExists(audioFileName) {
            return UNNotificationSound(named: UNNotificationSoundName(audioFileName))
        }

        return .default
    }

    /// 30초 확장 파일명 생성
    func extendedFileName(for originalFileName: String) -> String {
        let baseName = (originalFileName as NSString).deletingPathExtension
        return "\(baseName)_ext.caf"
    }

    /// Library/Sounds 디렉토리에 파일 존재 여부 확인
    func fileExists(_ fileName: String) -> Bool {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// 파일 크기 (bytes) 반환
    func fileSize(_ fileName: String) -> Int? {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int else {
            return nil
        }
        return size
    }

    /// Library/Sounds 디렉토리의 모든 파일 출력 (디버그용)
    func logAllSoundFiles() {
        #if DEBUG
        do {
            let files = try fileManager.contentsOfDirectory(atPath: soundsDirectory.path)
            print("📂 Library/Sounds: \(files.count)개 파일")
        } catch {
            print("❌ 디렉토리 읽기 실패")
        }
        #endif
    }
}
