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

    /// 알람에 맞는 UNNotificationSound 반환 (원본 파일 직접 사용)
    func notificationSound(for audioFileName: String?) -> UNNotificationSound {
        #if DEBUG
        print("🔊 [SoundService] audioFileName: \(audioFileName ?? "nil")")
        #endif

        guard let audioFileName, !audioFileName.isEmpty else {
            #if DEBUG
            print("🔊 [SoundService] → 기본 사운드 (파일명 없음)")
            #endif
            return .default
        }

        #if DEBUG
        print("🔊 [SoundService] 경로: \(soundsDirectory.path)")
        print("🔊 [SoundService] 파일 존재: \(fileExists(audioFileName))")
        #endif

        if fileExists(audioFileName) {
            #if DEBUG
            print("🔊 [SoundService] ✅ 원본 사용: \(audioFileName)")
            #endif
            return UNNotificationSound(named: UNNotificationSoundName(audioFileName))
        }

        #if DEBUG
        print("🔊 [SoundService] ❌ 파일 없음 → 기본 사운드")
        #endif
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
