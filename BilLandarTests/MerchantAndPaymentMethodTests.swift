import XCTest
@testable import BilLandar

@MainActor
final class MerchantAndPaymentMethodTests: XCTestCase {
    func testOfficialCancellationDomainIsVerified() {
        let result = MerchantCatalog.validate(
            "https://www.netflix.com/cancelplan",
            merchantName: "Netflix Premium"
        )
        guard case .verified(let entry) = result else {
            return XCTFail("Expected verified Netflix domain")
        }
        XCTAssertEqual(entry.id, "netflix")
    }

    func testUnrelatedAndInsecureCancellationLinksAreNotVerified() {
        XCTAssertEqual(
            MerchantCatalog.validate("https://example.com/cancel", merchantName: "Netflix"),
            .secureUnverified
        )
        XCTAssertEqual(
            MerchantCatalog.validate("http://netflix.com/cancel", merchantName: "Netflix"),
            .invalid
        )
    }

    func testPaymentMethodStoresOnlyLastFourDigits() {
        let method = PaymentMethod(
            name: "Personal Visa",
            type: .card,
            lastFour: "4111 1111 1111 4242"
        )
        XCTAssertEqual(method.lastFour, "4242")
        XCTAssertEqual(method.displayName, "Personal Visa •••• 4242")
    }

    func testBillOnlyExposesSecureCancellationLinks() {
        let bill = Bill(
            name: "Test",
            subtitle: "Plan",
            amount: 10,
            category: .other,
            cycle: .monthly,
            nextDueDate: .now,
            cancellationURLString: "http://example.com/cancel"
        )
        XCTAssertNil(bill.cancellationURL)

        bill.cancellationURLString = "https://example.com/cancel"
        XCTAssertEqual(bill.cancellationURL?.host, "example.com")
    }
}
