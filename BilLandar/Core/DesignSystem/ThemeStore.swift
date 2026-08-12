import Observation
import SwiftUI
import WidgetKit

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "System", locale: BilLandarSharedStore.appLocale)
        case .light: String(localized: "Light", locale: BilLandarSharedStore.appLocale)
        case .dark: String(localized: "Dark", locale: BilLandarSharedStore.appLocale)
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
@MainActor
final class ThemeStore {
    var mode: AppThemeMode {
        didSet {
            guard mode != oldValue else { return }
            BilLandarSharedStore.defaults.set(mode.rawValue, forKey: BilLandarSharedStore.Keys.themeMode)
        }
    }

    init() {
        BilLandarSharedStore.migrateLegacyDefaultsIfNeeded()
        let saved = BilLandarSharedStore.defaults.string(forKey: BilLandarSharedStore.Keys.themeMode)
        mode = AppThemeMode(rawValue: saved ?? "") ?? .system
    }
}

/// The app-level language choice. `system` keeps BilLandar aligned with the device
/// language, while the explicit choices override SwiftUI's locale for this app.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    /// Native names make the picker understandable even before a language is
    /// selected and avoid relying on a translated name for the language itself.
    var title: String {
        switch self {
        case .system: String(localized: "System", locale: BilLandarSharedStore.appLocale)
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }

    var locale: Locale {
        self == .system ? .current : Locale(identifier: rawValue)
    }
}

@Observable
@MainActor
final class AppLanguageStore {
    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            BilLandarSharedStore.defaults.set(language.rawValue, forKey: BilLandarSharedStore.Keys.languageIdentifier)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    init() {
        BilLandarSharedStore.migrateLegacyDefaultsIfNeeded()
        let saved = BilLandarSharedStore.defaults.string(forKey: BilLandarSharedStore.Keys.languageIdentifier)
        language = AppLanguage(rawValue: saved ?? "") ?? .system
    }

    var locale: Locale { language.locale }
}
