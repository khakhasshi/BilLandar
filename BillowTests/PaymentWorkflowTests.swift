import SwiftData
import XCTest
@testable import Billow

@MainActor
final class PaymentWorkflowTests: XCTestCase {
    func testConfirmAndUndoNewPaymentRestoresBill() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dueDate = try XCTUnwrap(Calendar.billow.date(from: DateComponents(year: 2026, month: 8, day: 15)))
        let bill = makeBill(dueDate: dueDate)
        context.insert(bill)
        try context.save()

        let receipt = try PaymentWorkflowService.confirmPayment(
            for: bill,
            payments: [],
            in: context,
            now: dueDate
        )

        XCTAssertTrue(receipt.insertedPayment)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PaymentRecord>()).count, 1)
        XCTAssertEqual(bill.nextDueDate, bill.renewalDate(after: dueDate))

        try PaymentWorkflowService.undo(receipt, for: bill, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PaymentRecord>()).count, 0)
        XCTAssertEqual(bill.nextDueDate, dueDate)
    }

    func testConfirmPendingPaymentAndUndoRestoresPendingStatus() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let bill = makeBill(dueDate: dueDate)
        let pending = PaymentRecord(
            billID: bill.id,
            billName: bill.name,
            amount: bill.amount,
            currencyCode: bill.currencyCode,
            paidAt: dueDate,
            dueDate: dueDate,
            status: .pending,
            note: "Awaiting confirmation"
        )
        context.insert(bill)
        context.insert(pending)
        try context.save()

        let receipt = try PaymentWorkflowService.confirmPayment(
            for: bill,
            payments: [pending],
            in: context,
            now: dueDate.addingTimeInterval(3_600)
        )
        XCTAssertEqual(pending.status, .paid)

        try PaymentWorkflowService.undo(receipt, for: bill, in: context)
        XCTAssertEqual(pending.status, .pending)
        XCTAssertEqual(pending.note, "Awaiting confirmation")
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Bill.self,
            PaymentRecord.self,
            PaymentMethod.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeBill(dueDate: Date) -> Bill {
        Bill(
            name: "Test Plan",
            subtitle: "Monthly",
            amount: 12,
            currencyCode: "USD",
            category: .productivity,
            cycle: .monthly,
            nextDueDate: dueDate,
            trialEndDate: dueDate
        )
    }
}
