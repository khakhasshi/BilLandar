import SwiftData
import SwiftUI

@main
struct BillioApp: App {
    private let modelContainer: ModelContainer
    @State private var exchangeRateStore = ExchangeRateStore()
    @State private var cloudSyncMonitor: CloudSyncMonitor
    @State private var notificationManager = NotificationManager()
    @State private var errorCenter = AppErrorCenter()

    init() {
        let result = DataStoreFactory.makeContainer()
        modelContainer = result.container
        _cloudSyncMonitor = State(
            initialValue: CloudSyncMonitor(usesCloudKitStore: result.usesCloudKit)
        )
        #if DEBUG && targetEnvironment(simulator)
        do {
            try SampleData.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            assertionFailure("Unable to seed Billio simulator data: \(error)")
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
        }
        .modelContainer(modelContainer)
    }
}
