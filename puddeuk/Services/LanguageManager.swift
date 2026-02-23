import Foundation
import SwiftUI
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage

    private let languageKey = "app_language"

    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Detect system language
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "ko"
            self.currentLanguage = systemLanguage.starts(with: "en") ? .english : .korean
        }
        applyLanguage()
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        applyLanguage()
    }

    private func applyLanguage() {
        UserDefaults.standard.set([currentLanguage.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    var needsRestart: Bool {
        return true // Language change requires app restart
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var code: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        }
    }

    var nativeName: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        }
    }

    var flag: String {
        switch self {
        case .korean:
            return "🇰🇷"
        case .english:
            return "🇺🇸"
        }
    }
}
