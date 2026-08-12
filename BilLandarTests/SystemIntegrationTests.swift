import XCTest
import SwiftData
@testable import BilLandar

@MainActor
final class SystemIntegrationTests: XCTestCase {
    private var previousCurrency: Any?
    private var previousLanguage: Any?
    private var previousSnapshot: Data?

    override func setUp() {
        super.setUp()
        let defaults = BilLandarSharedStore.defaults
        previousCurrency = defaults.object(forKey: BilLandarSharedStore.Keys.displayCurrency)
        previousLanguage = defaults.object(forKey: BilLandarSharedStore.Keys.languageIdentifier)
        previousSnapshot = defaults.data(forKey: snapshotKey)
        defaults.set("USD", forKey: BilLandarSharedStore.Keys.displayCurrency)
    }

    override func tearDown() {
        let defaults = BilLandarSharedStore.defaults
        if let previousCurrency {
            defaults.set(previousCurrency, forKey: BilLandarSharedStore.Keys.displayCurrency)
        } else {
            defaults.removeObject(forKey: BilLandarSharedStore.Keys.displayCurrency)
        }
        if let previousLanguage {
            defaults.set(previousLanguage, forKey: BilLandarSharedStore.Keys.languageIdentifier)
        } else {
            defaults.removeObject(forKey: BilLandarSharedStore.Keys.languageIdentifier)
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
        BilLandarSharedStore.defaults.set(try JSONEncoder().encode(snapshot), forKey: snapshotKey)

        let total = BilLandarSystemData.total(for: [(10, "USD"), (8, "EUR")])

        XCTAssertEqual(total.amount ?? -1, 20, accuracy: 0.0001)
        XCTAssertEqual(total.currencyCode, "USD")
    }

    func testWidgetTotalPreservesCurrenciesWhenRatesAreUnavailable() {
        BilLandarSharedStore.defaults.removeObject(forKey: snapshotKey)

        let total = BilLandarSystemData.total(for: [(10, "USD"), (8, "EUR")])

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
            BilLandarSharedStore.defaults.string(forKey: BilLandarSharedStore.Keys.languageIdentifier),
            AppLanguage.simplifiedChinese.rawValue
        )

        store.language = .japanese
        XCTAssertEqual(store.locale.identifier, "ja")
        XCTAssertEqual(
            BilLandarSharedStore.defaults.string(forKey: BilLandarSharedStore.Keys.languageIdentifier),
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
        let dueDate = Date.billandarDate(daysFromToday: 2)
        let bill = try BilLandarSystemActionService.addBill(
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

        _ = try BilLandarSystemActionService.pauseBill(id: bill.id, in: context)
        XCTAssertEqual(bill.status, .paused)

        bill.status = .active
        let paidAt = Date.now
        _ = try BilLandarSystemActionService.markPaid(id: bill.id, in: context, now: paidAt)

        let payments = try context.fetch(FetchDescriptor<PaymentRecord>())
        XCTAssertEqual(payments.count, 1)
        XCTAssertEqual(payments.first?.status, .paid)
        XCTAssertGreaterThan(bill.nextDueDate, dueDate)
    }

    func testVersionedSchemaKeepsAllPersistedModels() {
        XCTAssertEqual(BilLandarSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(Set(BilLandarSchemaV1.models.map { String(describing: $0) }), ["Bill", "PaymentRecord", "PaymentMethod"])
        XCTAssertEqual(BilLandarMigrationPlan.schemas.count, 1)
        XCTAssertTrue(BilLandarMigrationPlan.stages.isEmpty)
    }

    private var snapshotKey: String {
        "\(BilLandarSharedStore.Keys.exchangeRateSnapshotPrefix).USD"
    }
}
