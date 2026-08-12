import Observation
import UserNotifications

@Observable
@MainActor
final class NotificationManager {
    enum AuthorizationState: Equatable {
        case unknown
        case denied
        case authorized
        case provisional

        var title: String {
            switch self {
            case .unknown: String(localized: "Not configured", locale: BilLandarSharedStore.appLocale)
            case .denied: String(localized: "Disabled in Settings", locale: BilLandarSharedStore.appLocale)
            case .authorized: String(localized: "Enabled", locale: BilLandarSharedStore.appLocale)
            case .provisional: String(localized: "Quiet delivery", locale: BilLandarSharedStore.appLocale)
            }
        }
    }

    private(set) var authorizationState: AuthorizationState = .unknown
    private(set) var pendingReminderCount = 0
    private(set) var lastError: String?

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.enabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enabled) }
    }

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .billandar
    ) {
        self.center = center
        self.calendar = calendar
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral: authorizationState = .authorized
        case .provisional: authorizationState = .provisional
        case .denied: authorizationState = .denied
        case .notDetermined: authorizationState = .unknown
        @unknown default: authorizationState = .unknown
        }
        await refreshPendingCount()
    }

    @discardableResult
    func enableAndRequestAuthorization(for bills: [Bill]) async -> Bool {
        isEnabled = true
        lastError = nil
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
            if granted { await reschedule(for: bills) }
            return granted
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func disable() async {
        isEnabled = false
        let requests = await center.pendingNotificationRequests()
        let ids = requests.map(\.identifier).filter { $0.hasPrefix(Keys.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        pendingReminderCount = 0
    }

    func reschedule(for bills: [Bill]) async {
        lastError = nil
        guard isEnabled,
              authorizationState == .authorized || authorizationState == .provisional else { return }

        let existing = await center.pendingNotificationRequests()
        let billandarIDs = existing.map(\.identifier).filter { $0.hasPrefix(Keys.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: billandarIDs)
        let deliveredIDs = Set(await center.deliveredNotifications().map(\.request.identifier))

        let candidates = bills
            .filter { $0.status == .active && $0.reminderDaysBefore > 0 }
            .flatMap { reminderCandidates(for: $0) }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(60)

        for candidate in candidates where !deliveredIDs.contains(requestIdentifier(for: candidate.bill.id, dueDate: candidate.dueDate)) {
            await schedule(candidate)
        }
        await refreshPendingCount()
    }

    func cancelReminder(for billID: UUID) async {
        let requests = await center.pendingNotificationRequests()
        let prefix = requestPrefix(for: billID)
        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )
        await refreshPendingCount()
    }

    func scheduleReminder(for bill: Bill) async {
        lastError = nil
        await cancelReminder(for: bill.id)
        guard isEnabled,
              authorizationState == .authorized || authorizationState == .provisional,
              bill.status == .active else { return }
        let deliveredIDs = Set(await center.deliveredNotifications().map(\.request.identifier))
        for candidate in reminderCandidates(for: bill).prefix(12)
            where !deliveredIDs.contains(requestIdentifier(for: bill.id, dueDate: candidate.dueDate)) {
            await schedule(candidate)
        }
        await refreshPendingCount()
    }

    func reminderFireDate(for bill: Bill, occurrenceDate: Date? = nil, now: Date = .now) -> Date {
        let dueDate = occurrenceDate ?? bill.nextDueDate
        let preferredDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: calendar.date(
                byAdding: .day,
                value: -bill.reminderDaysBefore,
                to: dueDate
            ) ?? dueDate
        ) ?? dueDate
        return max(preferredDate, now.addingTimeInterval(5))
    }

    private func reminderCandidates(for bill: Bill, now: Date = .now) -> [ReminderCandidate] {
        guard bill.nextDueDate > now else { return [] }
        let horizon = calendar.date(byAdding: .month, value: 18, to: now) ?? now
        var dueDate = bill.nextDueDate
        var result: [ReminderCandidate] = []

        while dueDate <= horizon && result.count < 24 {
            result.append(
                ReminderCandidate(
                    bill: bill,
                    dueDate: dueDate,
                    fireDate: reminderFireDate(for: bill, occurrenceDate: dueDate, now: now)
                )
            )
            dueDate = bill.renewalDate(after: dueDate, calendar: calendar)
        }
        return result
    }

    private func schedule(_ candidate: ReminderCandidate) async {
        let bill = candidate.bill

        let content = UNMutableNotificationContent()
        let amount = bill.amount.formatted(.currency(code: bill.currencyCode).locale(BilLandarSharedStore.appLocale))
        let dueDate = candidate.dueDate.formatted(
            .dateTime.locale(BilLandarSharedStore.appLocale).month(.abbreviated).day()
        )
        content.title = String(localized: "Bill due soon", locale: BilLandarSharedStore.appLocale) + ": \(bill.name)"
        content.body = "\(amount) · "
            + String(localized: "Due", locale: BilLandarSharedStore.appLocale)
            + " \(dueDate)."
        content.sound = .default
        content.userInfo = [
            "billID": bill.id.uuidString,
            "dueDate": candidate.dueDate.timeIntervalSince1970
        ]
        content.threadIdentifier = "bill-reminders"

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: candidate.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier(for: bill.id, dueDate: candidate.dueDate),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshPendingCount() async {
        pendingReminderCount = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Keys.requestPrefix) }
            .count
    }

    private func requestPrefix(for billID: UUID) -> String {
        "\(Keys.requestPrefix)\(billID.uuidString)."
    }

    private func requestIdentifier(for billID: UUID, dueDate: Date) -> String {
        "\(requestPrefix(for: billID))\(Int(dueDate.timeIntervalSince1970))"
    }

    private enum Keys {
        static let enabled = "billRemindersEnabled"
        static let requestPrefix = "billandar.bill."
    }
}

private struct ReminderCandidate {
    let bill: Bill
    let dueDate: Date
    let fireDate: Date
}
