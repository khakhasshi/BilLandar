import Foundation

enum BillioSharedStore {
    static let appGroupIdentifier = "group.JIANGJINGZHE.Billio"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func migrateLegacyDefaultsIfNeeded() {
        let shared = defaults
        guard !shared.bool(forKey: Keys.didMigrateLegacyDefaults) else { return }

        let legacy = UserDefaults.standard
        for key in ["displayCurrencyCode", "currencyCode", "billioThemeMode"] {
            if shared.object(forKey: key) == nil, let value = legacy.object(forKey: key) {
                shared.set(value, forKey: key)
            }
        }
        shared.set(true, forKey: Keys.didMigrateLegacyDefaults)
    }

    enum Keys {
        static let didMigrateLegacyDefaults = "sharedStore.didMigrateLegacyDefaults"
        static let usesCloudKit = "sharedStore.usesCloudKit"
        static let displayCurrency = "displayCurrencyCode"
        static let exchangeRateSnapshotPrefix = "exchangeRateSnapshot"
        static let themeMode = "billioThemeMode"
    }
}
