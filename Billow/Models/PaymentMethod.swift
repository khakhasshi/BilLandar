import Foundation
import SwiftData

@Model
final class PaymentMethod {
    var id: UUID = UUID()
    var name: String = ""
    var typeRawValue: String = PaymentMethodType.card.rawValue
    var issuer: String = ""
    var lastFour: String = ""
    var isDefault: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        type: PaymentMethodType,
        issuer: String = "",
        lastFour: String = "",
        isDefault: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        typeRawValue = type.rawValue
        self.issuer = issuer
        self.lastFour = String(lastFour.filter(\.isNumber).suffix(4))
        self.isDefault = isDefault
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var type: PaymentMethodType {
        get { PaymentMethodType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    var displayName: String {
        let suffix = lastFour.isEmpty ? "" : " •••• \(lastFour)"
        return "\(name)\(suffix)"
    }
}

enum PaymentMethodType: String, CaseIterable, Identifiable {
    case card
    case applePay
    case bank
    case wallet
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .card: String(localized: "Card", locale: BillowSharedStore.appLocale)
        case .applePay: String(localized: "Apple Pay", locale: BillowSharedStore.appLocale)
        case .bank: String(localized: "Bank account", locale: BillowSharedStore.appLocale)
        case .wallet: String(localized: "Digital wallet", locale: BillowSharedStore.appLocale)
        case .other: String(localized: "Other", locale: BillowSharedStore.appLocale)
        }
    }

    var symbolName: String {
        switch self {
        case .card: "creditcard.fill"
        case .applePay: "apple.logo"
        case .bank: "building.columns.fill"
        case .wallet: "wallet.bifold.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}
