import Foundation
import SwiftData

struct PaymentMutationReceipt: Identifiable {
    let id = UUID()
    let payment: PaymentRecord
    let previousStatus: PaymentStatus
    let previousPaidAt: Date
    let previousNote: String
    let insertedPayment: Bool
    let previousDueDate: Date
    let previousTrialEndDate: Date?
    let message: String
}

@MainActor
enum PaymentWorkflowService {
    static func confirmPayment(
        for bill: Bill,
        payments: [PaymentRecord],
        in context: ModelContext,
        now: Date = .now
    ) throws -> PaymentMutationReceipt {
        let receipt: PaymentMutationReceipt

        if let pending = payments
            .filter({ $0.billID == bill.id && $0.status == .pending })
            .max(by: { $0.dueDate < $1.dueDate }) {
            receipt = makeReceipt(
                payment: pending,
                bill: bill,
                insertedPayment: false,
                message: "Payment recorded"
            )
            pending.status = .paid
            pending.paidAt = now
            pending.note = "Confirmed manually"
        } else {
            let payment = PaymentRecord(
                billID: bill.id,
                billName: bill.name,
                amount: bill.amount,
                currencyCode: bill.currencyCode,
                paidAt: now,
                dueDate: bill.nextDueDate,
                status: .paid,
                note: "Confirmed manually"
            )
            receipt = makeReceipt(
                payment: payment,
                bill: bill,
                insertedPayment: true,
                message: "Payment added"
            )
            context.insert(payment)
            bill.nextDueDate = bill.renewalDate(after: bill.nextDueDate)
        }

        bill.trialEndDate = nil
        bill.updatedAt = now
        try context.save()
        return receipt
    }

    static func update(
        _ payment: PaymentRecord,
        to status: PaymentStatus,
        for bill: Bill,
        in context: ModelContext,
        now: Date = .now
    ) throws -> PaymentMutationReceipt {
        let receipt = makeReceipt(
            payment: payment,
            bill: bill,
            insertedPayment: false,
            message: "Payment marked \(status.title.lowercased())"
        )
        payment.status = status
        if status == .paid { payment.paidAt = now }
        payment.note = "Updated manually"
        try context.save()
        return receipt
    }

    static func undo(
        _ receipt: PaymentMutationReceipt,
        for bill: Bill,
        in context: ModelContext
    ) throws {
        if receipt.insertedPayment {
            context.delete(receipt.payment)
        } else {
            receipt.payment.status = receipt.previousStatus
            receipt.payment.paidAt = receipt.previousPaidAt
            receipt.payment.note = receipt.previousNote
        }
        bill.nextDueDate = receipt.previousDueDate
        bill.trialEndDate = receipt.previousTrialEndDate
        bill.updatedAt = .now
        try context.save()
    }

    private static func makeReceipt(
        payment: PaymentRecord,
        bill: Bill,
        insertedPayment: Bool,
        message: String
    ) -> PaymentMutationReceipt {
        PaymentMutationReceipt(
            payment: payment,
            previousStatus: payment.status,
            previousPaidAt: payment.paidAt,
            previousNote: payment.note,
            insertedPayment: insertedPayment,
            previousDueDate: bill.nextDueDate,
            previousTrialEndDate: bill.trialEndDate,
            message: message
        )
    }
}
