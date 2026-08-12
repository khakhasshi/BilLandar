import SwiftData
import XCTest
@testable import Billow

@MainActor
final class BillLifecycleTests: XCTestCase {
    func testReconcileCreatesPendingOccurrencesAdvancesDueDateAndIsIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Bill.self,
            PaymentRecord.self,
            PaymentMethod.self,
            configurations: configuration
        )
        let context = container.mainContext
        let now = try XCTUnwrap(Calendar.billow.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12)))
        let firstDue = try XCTUnwrap(Calendar.billow.date(from: DateComponents(year: 2026, month: 6, day: 11)))
        let bill = Bill(
            name: "Lifecycle",
            subtitle: "Monthly",
            amount: 12,
            category: .other,
            cycle: .monthly,
            nextDueDate: firstDue
        )
        context.insert(bill)

        try BillLifecycleService.reconcile(bills: [bill], payments: [], in: context, now: now)
        var payments = try context.fetch(FetchDescriptor<PaymentRecord>())
        XCTAssertEqual(payments.count, 3)
        XCTAssertTrue(payments.allSatisfy { $0.status == .pending })
        XCTAssertEqual(
            Calendar.billow.dateComponents([.year, .month, .day], from: bill.nextDueDate),
            DateComponents(year: 2026, month: 9, day: 11)
        )

        try BillLifecycleService.reconcile(bills: [bill], payments: payments, in: context, now: now)
        payments = try context.fetch(FetchDescriptor<PaymentRecord>())
        XCTAssertEqual(payments.count, 3)
    }
}
