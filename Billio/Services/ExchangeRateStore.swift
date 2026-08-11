import Foundation
import Observation

@Observable
@MainActor
final class ExchangeRateStore {
    private(set) var snapshot: ExchangeRateSnapshot?
    private(set) var isLoading = false
    private(set) var isLoadingHistory = false
    private(set) var errorMessage: String?
    private(set) var historicalSnapshots: [ExchangeRateSnapshot] = []
    private(set) var historicalErrorMessage: String?

    var displayCurrency: String {
        didSet {
            guard displayCurrency != oldValue else { return }
            BillioSharedStore.defaults.set(displayCurrency, forKey: BillioSharedStore.Keys.displayCurrency)
            snapshot = nil
            historicalSnapshots = []
            errorMessage = nil
        }
    }

    private let provider: any ExchangeRateProviding
    private let cacheLifetime: TimeInterval = 12 * 60 * 60
    private var refreshRequestID: UUID?
    private var historyRequestID: UUID?

    init() {
        BillioSharedStore.migrateLegacyDefaultsIfNeeded()
        provider = FrankfurterExchangeRateProvider()
        displayCurrency = Self.savedDisplayCurrency
        loadCachedSnapshot()
    }

    init(provider: any ExchangeRateProviding) {
        BillioSharedStore.migrateLegacyDefaultsIfNeeded()
        self.provider = provider
        displayCurrency = Self.savedDisplayCurrency
        loadCachedSnapshot()
    }

    var dataStatusText: String {
        if isLoading { return String(localized: "Updating rates…") }
        if let errorMessage { return errorMessage }
        guard let snapshot else { return String(localized: "Rates not loaded") }
        return "Rates from \(snapshot.effectiveDate.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    var hasUsableRates: Bool {
        snapshot?.baseCurrency == displayCurrency
    }

    func refreshIfNeeded() async {
        if let snapshot,
           snapshot.baseCurrency == displayCurrency,
           Date.now.timeIntervalSince(snapshot.fetchedAt) < cacheLifetime {
            return
        }
        await refresh()
    }

    func refresh() async {
        let requestID = UUID()
        let requestedBaseCurrency = displayCurrency
        refreshRequestID = requestID
        isLoading = true
        errorMessage = nil

        do {
            let currencies = Set(Currency.supported.map(\.code))
            let latest = try await provider.latestRates(
                baseCurrency: requestedBaseCurrency,
                quoteCurrencies: currencies
            )
            guard refreshRequestID == requestID,
                  displayCurrency == requestedBaseCurrency else { return }
            snapshot = latest
            saveCachedSnapshot(latest)
        } catch {
            guard refreshRequestID == requestID else { return }
            if !(error is CancellationError) {
                errorMessage = String(localized: "Using original amounts · rates unavailable")
            }
        }

        if refreshRequestID == requestID { isLoading = false }
    }

    func setDisplayCurrency(_ currencyCode: String) async {
        displayCurrency = currencyCode
        loadCachedSnapshot()
        await refreshIfNeeded()
    }

    func convert(_ amount: Double, from sourceCurrency: String) -> Double? {
        if sourceCurrency == displayCurrency { return amount }
        guard snapshot?.baseCurrency == displayCurrency else { return nil }
        return snapshot?.convert(amount, from: sourceCurrency)
    }

    func convertedTotal<S: Sequence>(
        for bills: S,
        amount: (Bill) -> Double = { $0.amount }
    ) -> Double? where S.Element == Bill {
        var total = 0.0
        for bill in bills {
            guard let converted = convert(amount(bill), from: bill.currencyCode) else { return nil }
            total += converted
        }
        return total
    }

    func loadHistoricalRates(from startDate: Date, to endDate: Date, currencies: Set<String>) async {
        let requiredCurrencies = currencies.filter { $0 != displayCurrency }
        guard !requiredCurrencies.isEmpty else {
            historyRequestID = nil
            historicalSnapshots = []
            historicalErrorMessage = nil
            isLoadingHistory = false
            return
        }
        let requestID = UUID()
        let requestedBaseCurrency = displayCurrency
        historyRequestID = requestID
        isLoadingHistory = true
        historicalErrorMessage = nil

        do {
            let snapshots = try await provider.historicalRates(
                baseCurrency: requestedBaseCurrency,
                quoteCurrencies: requiredCurrencies,
                from: startDate,
                to: endDate
            )
            guard historyRequestID == requestID,
                  displayCurrency == requestedBaseCurrency else { return }
            historicalSnapshots = snapshots
        } catch {
            guard historyRequestID == requestID else { return }
            if !(error is CancellationError) {
                historicalErrorMessage = String(localized: "Historical rates unavailable")
            }
        }
        if historyRequestID == requestID { isLoadingHistory = false }
    }

    func historicalConvert(_ amount: Double, from sourceCurrency: String, at date: Date) -> Double? {
        if sourceCurrency == displayCurrency { return amount }
        guard let snapshot = historicalSnapshots
            .last(where: {
                $0.baseCurrency == displayCurrency
                    && $0.effectiveDate.startOfDay <= date.startOfDay
            }) else {
            return nil
        }
        return snapshot.convert(amount, from: sourceCurrency)
    }

    private func loadCachedSnapshot() {
        guard let data = BillioSharedStore.defaults.data(forKey: cacheKey(for: displayCurrency)),
              let cached = try? JSONDecoder().decode(ExchangeRateSnapshot.self, from: data),
              cached.baseCurrency == displayCurrency else {
            snapshot = nil
            return
        }
        snapshot = cached
    }

    private func saveCachedSnapshot(_ snapshot: ExchangeRateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        BillioSharedStore.defaults.set(data, forKey: cacheKey(for: snapshot.baseCurrency))
    }

    private func cacheKey(for baseCurrency: String) -> String {
        "\(BillioSharedStore.Keys.exchangeRateSnapshotPrefix).\(baseCurrency)"
    }

    private static var savedDisplayCurrency: String {
        BillioSharedStore.defaults.string(forKey: BillioSharedStore.Keys.displayCurrency)
            ?? BillioSharedStore.defaults.string(forKey: "currencyCode")
            ?? "USD"
    }
}
