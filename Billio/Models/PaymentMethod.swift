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
        case .card: "Card"
        case .applePay: "Apple Pay"
        case .bank: "Bank account"
        case .wallet: "Digital wallet"
        case .other: "Other"
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
