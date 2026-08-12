import XCTest
@testable import Billow

@MainActor
final class BillCycleTests: XCTestCase {
    func testRenewalDateAdvancesEachSupportedCycle() throws {
        let start = try XCTUnwrap(Calendar.billow.date(from: DateComponents(year: 2026, month: 1, day: 15)))
        let expectations: [(BillingCycle, DateComponents)] = [
            (.weekly, DateComponents(year: 2026, month: 1, day: 22)),
            (.monthly, DateComponents(year: 2026, month: 2, day: 15)),
            (.quarterly, DateComponents(year: 2026, month: 4, day: 15)),
            (.yearly, DateComponents(year: 2027, month: 1, day: 15))
        ]

        for (cycle, expectedComponents) in expectations {
            let bill = makeBill(cycle: cycle, dueDate: start)
            let expected = try XCTUnwrap(Calendar.billow.date(from: expectedComponents))
            XCTAssertEqual(bill.renewalDate(after: start), expected, "Failed for \(cycle)")
        }
    }

    func testMerchantNormalizationIsStable() {
        XCTAssertEqual(Bill.normalizedMerchantIdentifier(from: "  Nétflix Premium!  "), "netflix-premium")
    }

    func testReminderFireDateUsesConfiguredLeadTimeAtNineAM() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let dueDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 18))
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 12))
        )
        let bill = makeBill(cycle: .monthly, dueDate: dueDate)
        bill.reminderDaysBefore = 3

        let fireDate = NotificationManager(calendar: calendar)
            .reminderFireDate(for: bill, now: now)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 17)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    private func makeBill(cycle: BillingCycle, dueDate: Date) -> Bill {
        Bill(
            name: "Test",
            subtitle: "Plan",
            amount: 10,
            category: .other,
            cycle: cycle,
            nextDueDate: dueDate
        )
    }
}
