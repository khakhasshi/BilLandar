import Foundation
import SwiftData

@Model
final class Bill {
    var id: UUID = UUID()
    var name: String = ""
    var subtitle: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var categoryRawValue: String = BillCategory.other.rawValue
    var cycleRawValue: String = BillingCycle.monthly.rawValue
    var nextDueDate: Date = Date.now
    var statusRawValue: String = BillStatus.active.rawValue
    var notes: String = ""
    var reminderDaysBefore: Int = 1
    var symbolName: String = "creditcard.fill"
    var brandColorHex: String = "7357F6"
    var merchantIdentifier: String = ""
    var trialEndDate: Date?
    var cancellationURLString: String?
    var cancellationURLVerified: Bool = false
    var paymentMethodID: UUID?
    var paymentMethodLabel: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        amount: Double,
        currencyCode: String = "USD",
        category: BillCategory,
        cycle: BillingCycle,
        nextDueDate: Date,
        status: BillStatus = .active,
        notes: String = "",
        reminderDaysBefore: Int = 1,
        symbolName: String = "creditcard.fill",
        brandColorHex: String = "7357F6",
        merchantIdentifier: String = "",
        trialEndDate: Date? = nil,
        cancellationURLString: String? = nil,
        cancellationURLVerified: Bool = false,
        paymentMethodID: UUID? = nil,
        paymentMethodLabel: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.amount = amount
        self.currencyCode = currencyCode
        categoryRawValue = category.rawValue
        cycleRawValue = cycle.rawValue
        self.nextDueDate = nextDueDate
        statusRawValue = status.rawValue
        self.notes = notes
        self.reminderDaysBefore = reminderDaysBefore
        self.symbolName = symbolName
        self.brandColorHex = brandColorHex
        self.merchantIdentifier = merchantIdentifier.isEmpty
            ? Self.normalizedMerchantIdentifier(from: name)
            : merchantIdentifier
        self.trialEndDate = trialEndDate
        self.cancellationURLString = cancellationURLString
        self.cancellationURLVerified = cancellationURLVerified
        self.paymentMethodID = paymentMethodID
        self.paymentMethodLabel = paymentMethodLabel
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var category: BillCategory {
        get { BillCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var cycle: BillingCycle {
        get { BillingCycle(rawValue: cycleRawValue) ?? .monthly }
        set { cycleRawValue = newValue.rawValue }
    }

    var status: BillStatus {
        get { BillStatus(rawValue: statusRawValue) ?? .active }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var isTrial: Bool {
        guard let trialEndDate else { return false }
        return trialEndDate >= Date.now.startOfDay
    }

    var cancellationURL: URL? {
        guard let cancellationURLString,
              let url = URL(string: cancellationURLString),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    static func normalizedMerchantIdentifier(from name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: "-")
    }

    func renewalDate(after date: Date, calendar: Calendar = .billio) -> Date {
        switch cycle {
        case .weekly:
            calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

enum BillCategory: String, CaseIterable, Identifiable {
    case entertainment
    case productivity
    case storage
    case finance
    case utilities
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .entertainment: String(localized: "Entertainment", locale: BillioSharedStore.appLocale)
        case .productivity: String(localized: "Productivity", locale: BillioSharedStore.appLocale)
        case .storage: String(localized: "Storage", locale: BillioSharedStore.appLocale)
        case .finance: String(localized: "Finance", locale: BillioSharedStore.appLocale)
        case .utilities: String(localized: "Utilities", locale: BillioSharedStore.appLocale)
        case .other: String(localized: "Other", locale: BillioSharedStore.appLocale)
        }
    }

    var symbolName: String {
        switch self {
        case .entertainment: "play.tv.fill"
        case .productivity: "briefcase.fill"
        case .storage: "externaldrive.fill"
        case .finance: "banknote.fill"
        case .utilities: "bolt.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}

enum BillingCycle: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: Self { self }

    var title: String {
        switch self {
        case .weekly: String(localized: "Every week", locale: BillioSharedStore.appLocale)
        case .monthly: String(localized: "Every month", locale: BillioSharedStore.appLocale)
        case .quarterly: String(localized: "Every 3 months", locale: BillioSharedStore.appLocale)
        case .yearly: String(localized: "Every year", locale: BillioSharedStore.appLocale)
        }
    }
}

enum BillStatus: String, CaseIterable, Identifiable {
    case active
    case paused
    case cancelled

    var id: Self { self }
    var title: String {
        switch self {
        case .active: String(localized: "Active", locale: BillioSharedStore.appLocale)
        case .paused: String(localized: "Paused", locale: BillioSharedStore.appLocale)
        case .cancelled: String(localized: "Cancelled", locale: BillioSharedStore.appLocale)
        }
    }
}
