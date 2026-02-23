import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showingRestartAlert = false
    @State private var selectedLanguage: AppLanguage?

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.13).ignoresSafeArea()

            List {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            selectedLanguage = language
                            if language != languageManager.currentLanguage {
                                showingRestartAlert = true
                            }
                        } label: {
                            HStack {
                                Text(language.nativeName)
                                    .font(.omyuBody)
                                    .foregroundStyle(.white)

                                Spacer()

                                if language == languageManager.currentLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.teal)
                                        .font(.omyu(size: 16))
                                }
                            }
                        }
                        .listRowBackground(Color(red: 0.18, green: 0.18, blue: 0.2))
                    }
                } header: {
                    Text("language.section.available")
                        .font(.omyuCaption)
                        .foregroundStyle(.gray)
                } footer: {
                    Text("language.footer.restart")
                        .font(.omyuCaption)
                        .foregroundStyle(.gray)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("language.navigation.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("language.restart.alert.title", isPresented: $showingRestartAlert) {
            Button("button.cancel", role: .cancel) {
                selectedLanguage = nil
            }
            Button("language.restart.alert.confirm") {
                if let language = selectedLanguage {
                    languageManager.setLanguage(language)
                    AnalyticsManager.shared.logLanguageChanged(language: language.rawValue)
                    // Exit app to apply language change
                    exit(0)
                }
            }
        } message: {
            Text("language.restart.alert.message")
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
