import Foundation
import SwiftData

@MainActor
enum BillLifecycleService {
    static func reconcile(
        bills: [Bill],
        payments: [PaymentRecord],
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .billio
    ) throws {
        var knownOccurrences = Set(
            payments.map { occurrenceKey(billID: $0.billID, dueDate: $0.dueDate, calendar: calendar) }
        )
        var changed = false

        for bill in bills where bill.status == .active {
            var occurrence = bill.nextDueDate
            var safetyCounter = 0

            while occurrence.startOfDay <= now.startOfDay && safetyCounter < 120 {
                let key = occurrenceKey(billID: bill.id, dueDate: occurrence, calendar: calendar)
                if !knownOccurrences.contains(key) {
                    context.insert(
                        PaymentRecord(
                            billID: bill.id,
                            billName: bill.name,
                            amount: bill.amount,
                            currencyCode: bill.currencyCode,
                            paidAt: occurrence,
                            dueDate: occurrence,
                            status: .pending,
                            note: "Awaiting payment confirmation"
                        )
                    )
                    knownOccurrences.insert(key)
                    changed = true
                }

                occurrence = bill.renewalDate(after: occurrence, calendar: calendar)
                safetyCounter += 1
            }

            if occurrence != bill.nextDueDate {
                bill.nextDueDate = occurrence
                bill.updatedAt = now
                changed = true
            }
        }

        if changed { try context.save() }
    }

    private static func occurrenceKey(billID: UUID, dueDate: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        return "\(billID.uuidString)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
