import Foundation

enum BilLandarSharedStore {
    static let appGroupIdentifier = "group.JIANGJINGZHE.BilLandar"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// Locale used by model-backed labels that are rendered as `String` values
    /// rather than SwiftUI `LocalizedStringKey` values.
    static var appLocale: Locale {
        guard let identifier = defaults.string(forKey: Keys.languageIdentifier),
              identifier != "system" else {
            return .current
        }
        return Locale(identifier: identifier)
    }

    static func migrateLegacyDefaultsIfNeeded() {
        let shared = defaults
        guard !shared.bool(forKey: Keys.didMigrateLegacyDefaults) else { return }

        let legacy = UserDefaults.standard
        for key in ["displayCurrencyCode", "currencyCode", "billandarThemeMode"] {
            if shared.object(forKey: key) == nil, let value = legacy.object(forKey: key) {
                shared.set(value, forKey: key)
            }
        }
        shared.set(true, forKey: Keys.didMigrateLegacyDefaults)
    }

    enum Keys {
        static let didMigrateLegacyDefaults = "sharedStore.didMigrateLegacyDefaults"
        static let usesCloudKit = "sharedStore.usesCloudKit"
        static let cloudKitFallbackReason = "sharedStore.cloudKitFallbackReason"
        static let displayCurrency = "displayCurrencyCode"
        static let exchangeRateSnapshotPrefix = "exchangeRateSnapshot"
        static let themeMode = "billandarThemeMode"
        static let languageIdentifier = "billandarLanguageIdentifier"
    }
}
