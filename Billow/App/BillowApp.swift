import SwiftData
import SwiftUI
import AppIntents

@main
struct BillowApp: App {
    private let modelContainer: ModelContainer
    @State private var exchangeRateStore = ExchangeRateStore()
    @State private var cloudSyncMonitor: CloudSyncMonitor
    @State private var notificationManager = NotificationManager()
    @State private var errorCenter = AppErrorCenter()
    @State private var feedbackCenter = AppFeedbackCenter()
    @State private var themeStore = ThemeStore()
    @State private var languageStore = AppLanguageStore()

    init() {
        BillowAppShortcuts.updateAppShortcutParameters()
        let result = DataStoreFactory.makeContainer()
        modelContainer = result.container
        _cloudSyncMonitor = State(
            initialValue: CloudSyncMonitor(usesCloudKitStore: result.usesCloudKit)
        )
        #if DEBUG && targetEnvironment(simulator)
        do {
            try SampleData.migrateLegacySimulatorDataIfNeeded(in: modelContainer.mainContext)
            try SampleData.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            assertionFailure("Unable to seed Billow simulator data: \(error)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AppTheme.accent)
                .environment(exchangeRateStore)
                .environment(cloudSyncMonitor)
                .environment(notificationManager)
                .environment(errorCenter)
                .environment(feedbackCenter)
                .environment(themeStore)
                .environment(languageStore)
                .environment(\.locale, languageStore.locale)
                .preferredColorScheme(themeStore.mode.preferredColorScheme)
        }
        .modelContainer(modelContainer)
    }
}
