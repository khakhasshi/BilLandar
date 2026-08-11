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
            case .checking: String(localized: "Checking iCloud…")
            case .available: String(localized: "iCloud Sync Available")
            case .noAccount: String(localized: "Sign in to iCloud")
            case .restricted: String(localized: "iCloud access restricted")
            case .couldNotDetermine: String(localized: "iCloud status unavailable")
            case .localFallback: String(localized: "Local storage only")
            case .error: String(localized: "iCloud check failed")
            }
        }

        var detail: String {
            switch self {
            case .checking: String(localized: "Confirming account access")
            case .available: String(localized: "Changes sync through your private CloudKit database")
            case .noAccount: String(localized: "Add an iCloud account in Settings to enable sync")
            case .restricted: String(localized: "This device does not allow iCloud access")
            case .couldNotDetermine: String(localized: "Try again when the network is available")
            case .localFallback: String(localized: "Your data remains available on this device")
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
            case .temporarilyUnavailable: state = .error(String(localized: "iCloud is temporarily unavailable"))
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
            return "Last successful sync \(lastSuccessfulSyncAt.formatted(.relative(presentation: .named)))"
        }
        return state.detail
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        let eventName: String
        switch event.type {
        case .setup: eventName = String(localized: "Preparing iCloud sync")
        case .import: eventName = String(localized: "Downloading changes")
        case .export: eventName = String(localized: "Uploading changes")
        @unknown default: eventName = String(localized: "Syncing with iCloud")
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
            lastSyncError = event.error?.localizedDescription ?? String(localized: "iCloud sync failed")
            UserDefaults.standard.set(lastSyncError, forKey: Keys.lastSyncError)
        }
    }

    private enum Keys {
        static let lastSuccessfulSyncAt = "cloudSync.lastSuccessfulAt"
        static let lastSyncError = "cloudSync.lastError"
    }
}
