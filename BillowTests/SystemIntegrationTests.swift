import XCTest
import SwiftData
@testable import Billow

@MainActor
final class SystemIntegrationTests: XCTestCase {
    private var previousCurrency: Any?
    private var previousLanguage: Any?
    private var previousSnapshot: Data?

    override func setUp() {
        super.setUp()
        let defaults = BillowSharedStore.defaults
        previousCurrency = defaults.object(forKey: BillowSharedStore.Keys.displayCurrency)
        previousLanguage = defaults.object(forKey: BillowSharedStore.Keys.languageIdentifier)
        previousSnapshot = defaults.data(forKey: snapshotKey)
        defaults.set("USD", forKey: BillowSharedStore.Keys.displayCurrency)
    }

    override func tearDown() {
        let defaults = BillowSharedStore.defaults
        if let previousCurrency {
            defaults.set(previousCurrency, forKey: BillowSharedStore.Keys.displayCurrency)
        } else {
            defaults.removeObject(forKey: BillowSharedStore.Keys.displayCurrency)
        }
        if let previousLanguage {
            defaults.set(previousLanguage, forKey: BillowSharedStore.Keys.languageIdentifier)
        } else {
            defaults.removeObject(forKey: BillowSharedStore.Keys.languageIdentifier)
        }
        if let previousSnapshot {
            defaults.set(previousSnapshot, forKey: snapshotKey)
        } else {
            defaults.removeObject(forKey: snapshotKey)
        }
        super.tearDown()
    }

    func testWidgetTotalUsesSharedExchangeRateCache() throws {
        let snapshot = ExchangeRateSnapshot(
            baseCurrency: "USD",
            rates: ["USD": 1, "EUR": 0.8],
            effectiveDate: .now,
            fetchedAt: .now,
            source: "Test"
        )
        BillowSharedStore.defaults.set(try JSONEncoder().encode(snapshot), forKey: snapshotKey)

        let total = BillowSystemData.total(for: [(10, "USD"), (8, "EUR")])

        XCTAssertEqual(total.amount ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(total.currencyCode, "USD")
    }

    func testWidgetTotalPreservesCurrenciesWhenRatesAreUnavailable() {
        BillowSharedStore.defaults.removeObject(forKey: snapshotKey)

        let total = BillowSystemData.total(for: [(10, "USD"), (8, "EUR")])

        XCTAssertNil(total.amount)
        XCTAssertEqual(total.originalCurrencyBreakdown["USD"], 10)
        XCTAssertEqual(total.originalCurrencyBreakdown["EUR"], 8)
    }

    func testAllAppearanceModesHaveStablePersistenceValues() {
        XCTAssertEqual(Set(AppThemeMode.allCases.map(\.rawValue)), ["system", "light", "dark"])
        XCTAssertNil(AppThemeMode.system.preferredColorScheme)
        XCTAssertEqual(AppThemeMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppThemeMode.dark.preferredColorScheme, .dark)
    }

    func testSupportedLanguagesPersistAndExposeExpectedLocale() {
        XCTAssertEqual(
            Set(AppLanguage.allCases.map(\.rawValue)),
            ["system", "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es"]
        )

        let store = AppLanguageStore()
        store.language = .simplifiedChinese
        XCTAssertEqual(store.locale.identifier, "zh-Hans")
        XCTAssertEqual(
            BillowSharedStore.defaults.string(forKey: BillowSharedStore.Keys.languageIdentifier),
            AppLanguage.simplifiedChinese.rawValue
        )

        store.language = .japanese
        XCTAssertEqual(store.locale.identifier, "ja")
        XCTAssertEqual(
            BillowSharedStore.defaults.string(forKey: BillowSharedStore.Keys.languageIdentifier),
            AppLanguage.japanese.rawValue
        )
    }

    func testShortcutActionsAddPauseAndConfirmPayment() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Bill.self,
            PaymentRecord.self,
            PaymentMethod.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let dueDate = Date.billowDate(daysFromToday: 2)
        let bill = try BillowSystemActionService.addBill(
            name: "Pro Service",
            amount: 12,
            currencyCode: "USD",
            nextDueDate: dueDate,
            cycle: .monthly,
            category: .productivity,
            in: context
        )

        XCTAssertEqual(bill.name, "Pro Service")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Bill>()).count, 1)

        _ = try BillowSystemActionService.pauseBill(id: bill.id, in: context)
        XCTAssertEqual(bill.status, .paused)

        bill.status = .active
        let paidAt = Date.now
        _ = try BillowSystemActionService.markPaid(id: bill.id, in: context, now: paidAt)

        let payments = try context.fetch(FetchDescriptor<PaymentRecord>())
        XCTAssertEqual(payments.count, 1)
        XCTAssertEqual(payments.first?.status, .paid)
        XCTAssertGreaterThan(bill.nextDueDate, dueDate)
    }

    func testVersionedSchemaKeepsAllPersistedModels() {
        XCTAssertEqual(BillowSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(Set(BillowSchemaV1.models.map { String(describing: $0) }), ["Bill", "PaymentRecord", "PaymentMethod"])
        XCTAssertEqual(BillowMigrationPlan.schemas.count, 1)
        XCTAssertTrue(BillowMigrationPlan.stages.isEmpty)
    }

    private var snapshotKey: String {
        "\(BillowSharedStore.Keys.exchangeRateSnapshotPrefix).USD"
    }
}
