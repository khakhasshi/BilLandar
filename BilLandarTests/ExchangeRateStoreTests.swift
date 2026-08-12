import XCTest
@testable import BilLandar

private struct MockExchangeRateProvider: ExchangeRateProviding {
    let rates: [String: Double]
    var history: [ExchangeRateSnapshot] = []

    func latestRates(baseCurrency: String, quoteCurrencies: Set<String>) async throws -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(
            baseCurrency: baseCurrency,
            rates: rates.merging([baseCurrency: 1]) { current, _ in current },
            effectiveDate: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: .now,
            source: "Test rates"
        )
    }

    func historicalRates(
        baseCurrency: String,
        quoteCurrencies: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [ExchangeRateSnapshot] {
        history
    }
}

@MainActor
final class ExchangeRateStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("USD", forKey: "displayCurrencyCode")
        UserDefaults.standard.removeObject(forKey: "exchangeRateSnapshot.USD")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "exchangeRateSnapshot.USD")
        UserDefaults.standard.removeObject(forKey: "displayCurrencyCode")
        super.tearDown()
    }

    func testConversionAndMixedCurrencyTotal() async throws {
        let store = ExchangeRateStore(provider: MockExchangeRateProvider(rates: ["EUR": 0.8]))
        await store.refresh()

        let converted = try XCTUnwrap(store.convert(10, from: "EUR"))
        XCTAssertEqual(converted, 12.5, accuracy: 0.0001)

        let usd = makeBill(amount: 10, currency: "USD")
        let eur = makeBill(amount: 8, currency: "EUR")
        let total = try XCTUnwrap(store.convertedTotal(for: [usd, eur]))
        XCTAssertEqual(total, 20, accuracy: 0.0001)
    }

    func testMissingRateDoesNotMixCurrencies() async {
        let store = ExchangeRateStore(provider: MockExchangeRateProvider(rates: ["EUR": 0.8]))
        await store.refresh()

        let usd = makeBill(amount: 10, currency: "USD")
        let jpy = makeBill(amount: 1_000, currency: "JPY")
        XCTAssertNil(store.convertedTotal(for: [usd, jpy]))
    }

    func testHistoricalConversionUsesPaymentDateRate() async throws {
        let historicalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let historical = ExchangeRateSnapshot(
            baseCurrency: "USD",
            rates: ["USD": 1, "EUR": 0.5],
            effectiveDate: historicalDate,
            fetchedAt: .now,
            source: "Test history"
        )
        let store = ExchangeRateStore(
            provider: MockExchangeRateProvider(rates: ["EUR": 0.8], history: [historical])
        )
        await store.loadHistoricalRates(
            from: historicalDate,
            to: historicalDate,
            currencies: ["EUR"]
        )

        let converted = try XCTUnwrap(store.historicalConvert(10, from: "EUR", at: historicalDate))
        XCTAssertEqual(converted, 20, accuracy: 0.0001)
    }

    private func makeBill(amount: Double, currency: String) -> Bill {
        Bill(
            name: "Test",
            subtitle: "Plan",
            amount: amount,
            currencyCode: currency,
            category: .other,
            cycle: .monthly,
            nextDueDate: .now
        )
    }
}
