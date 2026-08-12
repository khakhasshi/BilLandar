import CloudKit
import CoreData
import Observation

@Observable
@MainActor
final class CloudSyncMonitor {
    enum State: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case localFallback
        case error(String)

        var title: String {
            switch self {
            case .checking: String(localized: "Checking iCloud…", locale: BillowSharedStore.appLocale)
            case .available: String(localized: "iCloud Sync Available", locale: BillowSharedStore.appLocale)
            case .noAccount: String(localized: "Sign in to iCloud", locale: BillowSharedStore.appLocale)
            case .restricted: String(localized: "iCloud access restricted", locale: BillowSharedStore.appLocale)
            case .couldNotDetermine: String(localized: "iCloud status unavailable", locale: BillowSharedStore.appLocale)
            case .localFallback: String(localized: "Local storage only", locale: BillowSharedStore.appLocale)
            case .error: String(localized: "iCloud check failed", locale: BillowSharedStore.appLocale)
            }
        }

        var detail: String {
            switch self {
            case .checking: String(localized: "Confirming account access", locale: BillowSharedStore.appLocale)
            case .available: String(localized: "Changes sync through your private CloudKit database", locale: BillowSharedStore.appLocale)
            case .noAccount: String(localized: "Add an iCloud account in Settings to enable sync", locale: BillowSharedStore.appLocale)
            case .restricted: String(localized: "This device does not allow iCloud access", locale: BillowSharedStore.appLocale)
            case .couldNotDetermine: String(localized: "Try again when the network is available", locale: BillowSharedStore.appLocale)
            case .localFallback: String(localized: "Your data remains available on this device", locale: BillowSharedStore.appLocale)
            case .error(let message): message
            }
        }
    }

    private(set) var state: State
    private(set) var lastCheckedAt: Date?
    private(set) var lastSuccessfulSyncAt: Date?
    private(set) var lastSyncError: String?
    private(set) var activeEventTitle: String?
    let usesCloudKitStore: Bool

    private let container: CKContainer?

    init(usesCloudKitStore: Bool) {
        self.usesCloudKitStore = usesCloudKitStore
        state = usesCloudKitStore ? .checking : .localFallback
        lastSuccessfulSyncAt = UserDefaults.standard.object(forKey: Keys.lastSuccessfulSyncAt) as? Date
        lastSyncError = UserDefaults.standard.string(forKey: Keys.lastSyncError)
        container = usesCloudKitStore
            ? CKContainer(identifier: DataStoreFactory.cloudContainerIdentifier)
            : nil
    }

    func refresh() async {
        guard usesCloudKitStore, let container else {
            state = .localFallback
            return
        }

        state = .checking
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: state = .available
            case .noAccount: state = .noAccount
            case .restricted: state = .restricted
            case .couldNotDetermine: state = .couldNotDetermine
            case .temporarilyUnavailable: state = .error(String(localized: "iCloud is temporarily unavailable", locale: BillowSharedStore.appLocale))
            @unknown default: state = .couldNotDetermine
            }
        } catch {
            state = .error(error.localizedDescription)
        }
        lastCheckedAt = .now
    }

    func monitorEvents() async {
        guard usesCloudKitStore else { return }
        for await notification in NotificationCenter.default.notifications(
            named: NSPersistentCloudKitContainer.eventChangedNotification
        ) {
            guard !Task.isCancelled else { return }
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { continue }
            handle(event)
        }
    }

    var syncDetail: String {
        guard state == .available else { return state.detail }
        if let activeEventTitle { return activeEventTitle }
        if let lastSyncError { return lastSyncError }
        if let lastSuccessfulSyncAt {
            let relativeDate = lastSuccessfulSyncAt.formatted(
                .relative(presentation: .named).locale(BillowSharedStore.appLocale)
            )
            return String(
                format: String(localized: "Last successful sync %@", locale: BillowSharedStore.appLocale),
                relativeDate
            )
        }
        return state.detail
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        let eventName: String
        switch event.type {
        case .setup: eventName = String(localized: "Preparing iCloud sync", locale: BillowSharedStore.appLocale)
        case .import: eventName = String(localized: "Downloading changes", locale: BillowSharedStore.appLocale)
        case .export: eventName = String(localized: "Uploading changes", locale: BillowSharedStore.appLocale)
        @unknown default: eventName = String(localized: "Syncing with iCloud", locale: BillowSharedStore.appLocale)
        }

        guard event.endDate != nil else {
            activeEventTitle = eventName
            lastSyncError = nil
            return
        }

        activeEventTitle = nil
        if event.succeeded {
            lastSuccessfulSyncAt = event.endDate
            lastSyncError = nil
            UserDefaults.standard.set(event.endDate, forKey: Keys.lastSuccessfulSyncAt)
            UserDefaults.standard.removeObject(forKey: Keys.lastSyncError)
        } else {
            lastSyncError = event.error?.localizedDescription ?? String(localized: "iCloud sync failed", locale: BillowSharedStore.appLocale)
            UserDefaults.standard.set(lastSyncError, forKey: Keys.lastSyncError)
        }
    }

    private enum Keys {
        static let lastSuccessfulSyncAt = "cloudSync.lastSuccessfulAt"
        static let lastSyncError = "cloudSync.lastError"
    }
}
