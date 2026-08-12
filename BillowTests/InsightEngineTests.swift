import XCTest
@testable import Billow

@MainActor
final class InsightEngineTests: XCTestCase {
    func testDetectsHighValueProductInsights() throws {
        let now = try XCTUnwrap(Calendar.billow.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12)))
        let netflix = makeBill(name: "Netflix", merchant: "netflix", dueIn: 1, now: now)
        let duplicate = makeBill(name: "Netflix Family", merchant: "netflix", dueIn: 2, now: now)
        let trial = makeBill(name: "Notion AI", merchant: "notion", dueIn: 3, now: now)
        trial.trialEndDate = Calendar.billow.date(byAdding: .day, value: 2, to: now)
        let failed = makeBill(name: "Adobe", merchant: "adobe", dueIn: 4, now: now)

        let payments = [
            PaymentRecord(billID: netflix.id, billName: netflix.name, amount: 10, currencyCode: "USD", paidAt: Calendar.billow.date(byAdding: .month, value: -2, to: now)!, status: .paid),
            PaymentRecord(billID: netflix.id, billName: netflix.name, amount: 12, currencyCode: "USD", paidAt: Calendar.billow.date(byAdding: .month, value: -1, to: now)!, status: .paid),
            PaymentRecord(billID: failed.id, billName: failed.name, amount: 20, currencyCode: "USD", paidAt: now, status: .failed)
        ]

        let insights = InsightEngine.generate(
            bills: [netflix, duplicate, trial, failed],
            payments: payments,
            now: now
        )
        let kinds = Set(insights.map(\.kind))

        XCTAssertTrue(kinds.contains(.duplicate))
        XCTAssertTrue(kinds.contains(.priceIncrease))
        XCTAssertTrue(kinds.contains(.trialEnding))
        XCTAssertTrue(kinds.contains(.paymentIssue))
        XCTAssertTrue(kinds.contains(.renewalCluster))
        XCTAssertEqual(insights.first?.severity, .critical)
    }

    func testPausedBillsAreExcluded() {
        let active = makeBill(name: "Service", merchant: "same", dueIn: 1)
        let paused = makeBill(name: "Service Old", merchant: "same", dueIn: 2)
        paused.status = .paused

        let insights = InsightEngine.generate(bills: [active, paused], payments: [])
        XCTAssertFalse(insights.contains { $0.kind == .duplicate })
    }

    private func makeBill(
        name: String,
        merchant: String,
        dueIn days: Int,
        now: Date = .now
    ) -> Bill {
        Bill(
            name: name,
            subtitle: "Plan",
            amount: 10,
            category: .productivity,
            cycle: .monthly,
            nextDueDate: Calendar.billow.date(byAdding: .day, value: days, to: now)!,
            merchantIdentifier: merchant
        )
    }
}
