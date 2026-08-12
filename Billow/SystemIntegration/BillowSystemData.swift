import Foundation
import SwiftData

struct BillowSystemBill: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let subtitle: String
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date
    let status: BillStatus
    let symbolName: String
    let brandColorHex: String

    init(
        id: UUID,
        name: String,
        subtitle: String,
        amount: Double,
        currencyCode: String,
        nextDueDate: Date,
        status: BillStatus,
        symbolName: String,
        brandColorHex: String
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.amount = amount
        self.currencyCode = currencyCode
        self.nextDueDate = nextDueDate
        self.status = status
        self.symbolName = symbolName
        self.brandColorHex = brandColorHex
    }

    init(_ bill: Bill) {
        self.init(
            id: bill.id,
            name: bill.name,
            subtitle: bill.subtitle,
            amount: bill.amount,
            currencyCode: bill.currencyCode,
            nextDueDate: bill.nextDueDate,
            status: bill.status,
            symbolName: bill.symbolName,
            brandColorHex: bill.brandColorHex
        )
    }
}

struct BillowSystemTotal: Sendable {
    let amount: Double?
    let currencyCode: String
    let originalCurrencyBreakdown: [String: Double]

    var formatted: String {
        if let amount {
            return amount.formatted(.currency(code: currencyCode))
        }
        if originalCurrencyBreakdown.isEmpty {
            return String(localized: "No payments", locale: BillowSharedStore.appLocale)
        }
        return originalCurrencyBreakdown
            .keys
            .sorted()
            .map { code in
                (originalCurrencyBreakdown[code] ?? 0).formatted(.currency(code: code))
            }
            .joined(separator: " + ")
    }
}

@MainActor
enum BillowSystemData {
    static func makeContainer() throws -> ModelContainer {
        try DataStoreFactory.makeExtensionContainer()
    }

    static func activeBills(in context: ModelContext) throws -> [Bill] {
        let active = BillStatus.active.rawValue
        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate { $0.statusRawValue == active },
            sortBy: [SortDescriptor(\Bill.nextDueDate)]
        )
        return try context.fetch(descriptor)
    }

    static func bill(id: UUID, in context: ModelContext) throws -> Bill? {
        let descriptor = FetchDescriptor<Bill>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    static func payments(for billID: UUID, in context: ModelContext) throws -> [PaymentRecord] {
        let descriptor = FetchDescriptor<PaymentRecord>(predicate: #Predicate { $0.billID == billID })
        return try context.fetch(descriptor)
    }

    static func nextBills(limit: Int, now: Date = .now, in context: ModelContext) throws -> [BillowSystemBill] {
        Array(try activeBills(in: context).filter { $0.nextDueDate >= now.startOfDay }.prefix(limit))
            .map(BillowSystemBill.init)
    }

    static func monthlySpending(now: Date = .now, in context: ModelContext) throws -> BillowSystemTotal {
        let calendar = Calendar.billow
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            return BillowSystemTotal(amount: 0, currencyCode: displayCurrency, originalCurrencyBreakdown: [:])
        }
        let paid = PaymentStatus.paid.rawValue
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<PaymentRecord>(
            predicate: #Predicate {
                $0.statusRawValue == paid && $0.paidAt >= start && $0.paidAt < end
            }
        )
        let records = try context.fetch(descriptor)
        return total(for: records.map { ($0.amount, $0.currencyCode) })
    }

    static func total(for values: [(Double, String)]) -> BillowSystemTotal {
        let breakdown = Dictionary(grouping: values, by: { $0.1 })
            .mapValues { $0.reduce(0) { $0 + $1.0 } }
        guard !values.isEmpty else {
            return BillowSystemTotal(amount: 0, currencyCode: displayCurrency, originalCurrencyBreakdown: [:])
        }

        let base = displayCurrency
        guard let snapshot = cachedRates, snapshot.baseCurrency == base else {
            if breakdown.count == 1, let only = breakdown.first {
                return BillowSystemTotal(amount: only.value, currencyCode: only.key, originalCurrencyBreakdown: breakdown)
            }
            return BillowSystemTotal(amount: nil, currencyCode: base, originalCurrencyBreakdown: breakdown)
        }

        var convertedTotal = 0.0
        for (amount, source) in values {
            guard let converted = snapshot.convert(amount, from: sourceCurrency(source)) else {
                return BillowSystemTotal(amount: nil, currencyCode: base, originalCurrencyBreakdown: breakdown)
            }
            convertedTotal += converted
        }
        return BillowSystemTotal(amount: convertedTotal, currencyCode: base, originalCurrencyBreakdown: breakdown)
    }

    static var displayCurrency: String {
        BillowSharedStore.defaults.string(forKey: BillowSharedStore.Keys.displayCurrency) ?? "USD"
    }

    private static var cachedRates: ExchangeRateSnapshot? {
        let key = "\(BillowSharedStore.Keys.exchangeRateSnapshotPrefix).\(displayCurrency)"
        guard let data = BillowSharedStore.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ExchangeRateSnapshot.self, from: data)
    }

    private static func sourceCurrency(_ code: String) -> String { code }
}

@MainActor
enum BillowSystemActionService {
    @discardableResult
    static func addBill(
        name: String,
        amount: Double,
        currencyCode: String,
        nextDueDate: Date,
        cycle: BillingCycle,
        category: BillCategory,
        in context: ModelContext
    ) throws -> Bill {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else { throw BillowIntentError.invalidBill }
        let bill = Bill(
            name: trimmed,
            subtitle: cycle.title,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            cycle: cycle,
            nextDueDate: nextDueDate,
            symbolName: category.symbolName
        )
        context.insert(bill)
        try context.save()
        return bill
    }

    static func pauseBill(id: UUID, in context: ModelContext) throws -> Bill {
        guard let bill = try BillowSystemData.bill(id: id, in: context) else {
            throw BillowIntentError.billNotFound
        }
        guard bill.status != .cancelled else { throw BillowIntentError.cancelledBill }
        bill.status = .paused
        try context.save()
        return bill
    }

    static func markPaid(id: UUID, in context: ModelContext, now: Date = .now) throws -> Bill {
        guard let bill = try BillowSystemData.bill(id: id, in: context) else {
            throw BillowIntentError.billNotFound
        }
        guard bill.status == .active else { throw BillowIntentError.inactiveBill }
        let payments = try BillowSystemData.payments(for: bill.id, in: context)
        _ = try PaymentWorkflowService.confirmPayment(
            for: bill,
            payments: payments,
            in: context,
            now: now
        )
        return bill
    }
}
