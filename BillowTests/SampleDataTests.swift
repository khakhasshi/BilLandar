import SwiftData
import XCTest
@testable import Billow

@MainActor
final class SampleDataTests: XCTestCase {
    func testSampleDataIsRichConsistentAndIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Bill.self,
            PaymentRecord.self,
            PaymentMethod.self,
            configurations: configuration
        )
        let context = container.mainContext

        try SampleData.seedIfNeeded(in: context)
        try SampleData.seedIfNeeded(in: context)

        let bills = try context.fetch(FetchDescriptor<Bill>())
        let payments = try context.fetch(FetchDescriptor<PaymentRecord>())
        let methods = try context.fetch(FetchDescriptor<PaymentMethod>())

        XCTAssertEqual(bills.count, 10)
        XCTAssertGreaterThan(payments.count, 30)
        XCTAssertEqual(methods.count, 3)
        XCTAssertTrue(bills.contains { $0.paymentMethodID != nil })
        XCTAssertGreaterThanOrEqual(Set(bills.map(\.currencyCode)).count, 4)
        XCTAssertTrue(bills.contains { $0.trialEndDate != nil })
        XCTAssertTrue(bills.contains { $0.status == .paused })
        XCTAssertTrue(payments.contains { $0.status == .failed })
        let realBrandNames = ["Netflix", "Spotify", "iCloud+", "ChatGPT Plus", "YouTube Premium", "Disney+", "Amazon Prime"]
        XCTAssertTrue(Set(bills.map(\.name).filter { realBrandNames.contains($0) }).isEmpty)

        let insightKinds = Set(InsightEngine.generate(bills: bills, payments: payments).map(\.kind))
        XCTAssertTrue(insightKinds.contains(.duplicate))
        XCTAssertTrue(insightKinds.contains(.priceIncrease))
        XCTAssertTrue(insightKinds.contains(.trialEnding))
        XCTAssertTrue(insightKinds.contains(.paymentIssue))
    }
}
