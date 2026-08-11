import Foundation
import SwiftData

@Model
final class PaymentRecord {
    var id: UUID = UUID()
    var billID: UUID = UUID()
    var billName: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var paidAt: Date = Date.now
    var dueDate: Date = Date.now
    var statusRawValue: String = PaymentStatus.paid.rawValue
    var note: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        billID: UUID,
        billName: String,
        amount: Double,
        currencyCode: String,
        paidAt: Date,
        dueDate: Date? = nil,
        status: PaymentStatus = .paid,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.billID = billID
        self.billName = billName
        self.amount = amount
        self.currencyCode = currencyCode
        self.paidAt = paidAt
        self.dueDate = dueDate ?? paidAt
        statusRawValue = status.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    var status: PaymentStatus {
        get { PaymentStatus(rawValue: statusRawValue) ?? .paid }
        set { statusRawValue = newValue.rawValue }
    }
}

extension PaymentRecord {
    var isExpense: Bool { status == .paid }
}

enum PaymentStatus: String, CaseIterable, Identifiable {
    case paid
    case pending
    case failed
    case refunded

    var id: Self { self }
    var title: String {
        switch self {
        case .paid: String(localized: "Paid")
        case .pending: String(localized: "Pending")
        case .failed: String(localized: "Failed")
        case .refunded: String(localized: "Refunded")
        }
    }
}
