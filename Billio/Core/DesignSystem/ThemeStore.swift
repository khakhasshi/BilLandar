import Observation
import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
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
            BillioSharedStore.defaults.set(mode.rawValue, forKey: BillioSharedStore.Keys.themeMode)
        }
    }

    init() {
        BillioSharedStore.migrateLegacyDefaultsIfNeeded()
        let saved = BillioSharedStore.defaults.string(forKey: BillioSharedStore.Keys.themeMode)
        mode = AppThemeMode(rawValue: saved ?? "") ?? .system
    }
}
