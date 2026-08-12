import AppIntents
import SwiftData
import WidgetKit

struct BillEntity: AppEntity, Identifiable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bill")
    static let defaultQuery = BillEntityQuery()

    let id: UUID
    let name: String
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date

    init(id: UUID, name: String, amount: Double, currencyCode: String, nextDueDate: Date) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.nextDueDate = nextDueDate
    }

    init(_ bill: Bill) {
        self.init(
            id: bill.id,
            name: bill.name,
            amount: bill.amount,
            currencyCode: bill.currencyCode,
            nextDueDate: bill.nextDueDate
        )
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(amount.formatted(.currency(code: currencyCode))) · \(nextDueDate.formatted(.dateTime.month(.abbreviated).day()))"
        )
    }
}

struct BillEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [BillEntity.ID]) async throws -> [BillEntity] {
        let container = try BilLandarSystemData.makeContainer()
        let context = ModelContext(container)
        let bills = try context.fetch(FetchDescriptor<Bill>())
        let wanted = Set(identifiers)
        return bills.filter { wanted.contains($0.id) }.map(BillEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [BillEntity] {
        let container = try BilLandarSystemData.makeContainer()
        let context = ModelContext(container)
        return try BilLandarSystemData.activeBills(in: context).prefix(10).map(BillEntity.init)
    }
}

enum IntentCurrency: String, AppEnum {
    case usd = "USD", cny = "CNY", eur = "EUR", gbp = "GBP", jpy = "JPY"
    case hkd = "HKD", sgd = "SGD", aud = "AUD", cad = "CAD", chf = "CHF"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Currency")
    static let caseDisplayRepresentations: [IntentCurrency: DisplayRepresentation] = [
        .usd: "US Dollar (USD)", .cny: "Chinese Yuan (CNY)", .eur: "Euro (EUR)",
        .gbp: "British Pound (GBP)", .jpy: "Japanese Yen (JPY)", .hkd: "Hong Kong Dollar (HKD)",
        .sgd: "Singapore Dollar (SGD)", .aud: "Australian Dollar (AUD)",
        .cad: "Canadian Dollar (CAD)", .chf: "Swiss Franc (CHF)"
    ]
}

enum IntentBillingCycle: String, AppEnum {
    case weekly, monthly, quarterly, yearly

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Billing Cycle")
    static let caseDisplayRepresentations: [IntentBillingCycle: DisplayRepresentation] = [
        .weekly: "Weekly", .monthly: "Monthly", .quarterly: "Every 3 months", .yearly: "Yearly"
    ]

    var billCycle: BillingCycle { BillingCycle(rawValue: rawValue) ?? .monthly }
}

enum IntentBillCategory: String, AppEnum {
    case entertainment, productivity, storage, finance, utilities, other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static let caseDisplayRepresentations: [IntentBillCategory: DisplayRepresentation] = [
        .entertainment: "Entertainment", .productivity: "Productivity", .storage: "Storage",
        .finance: "Finance", .utilities: "Utilities", .other: "Other"
    ]

    var billCategory: BillCategory { BillCategory(rawValue: rawValue) ?? .other }
}

struct MonthlySpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Monthly Spending"
    static let description = IntentDescription("Shows the total of confirmed payments recorded this month.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try BilLandarSystemData.makeContainer()
        let total = try BilLandarSystemData.monthlySpending(in: ModelContext(container))
        return .result(dialog: "Your confirmed BilLandar spending this month is \(total.formatted).")
    }
}

struct AddBillIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Bill"
    static let description = IntentDescription("Adds a recurring bill to BilLandar.")

    @Parameter(title: "Name") var name: String
    @Parameter(title: "Amount", inclusiveRange: (0.01, 1_000_000)) var amount: Double
    @Parameter(title: "Currency", default: .usd) var currency: IntentCurrency
    @Parameter(title: "Next Due Date") var nextDueDate: Date
    @Parameter(title: "Billing Cycle", default: .monthly) var billingCycle: IntentBillingCycle
    @Parameter(title: "Category", default: .other) var category: IntentBillCategory

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) for \(\.$amount) \(\.$currency) due \(\.$nextDueDate)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try BilLandarSystemData.makeContainer()
        let context = ModelContext(container)
        let bill = try BilLandarSystemActionService.addBill(
            name: name,
            amount: amount,
            currencyCode: currency.rawValue,
            nextDueDate: nextDueDate,
            cycle: billingCycle.billCycle,
            category: category.billCategory,
            in: context
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Added \(bill.name) to BilLandar.")
    }
}

struct PauseBillIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Bill"
    static let description = IntentDescription("Pauses an active recurring bill in BilLandar.")

    @Parameter(title: "Bill") var bill: BillEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Pause \(\.$bill)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try BilLandarSystemData.makeContainer()
        let context = ModelContext(container)
        let storedBill = try BilLandarSystemActionService.pauseBill(id: bill.id, in: context)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Paused \(storedBill.name).")
    }
}

struct MarkBillPaidIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Bill Paid"
    static let description = IntentDescription("Records a confirmed payment and advances the bill's next due date.")

    @Parameter(title: "Bill") var bill: BillEntity

    init() {}

    init(bill: BillEntity) {
        self.bill = bill
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$bill) as paid")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try BilLandarSystemData.makeContainer()
        let context = ModelContext(container)
        let storedBill = try BilLandarSystemActionService.markPaid(id: bill.id, in: context)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Marked \(storedBill.name) as paid. The next due date is \(storedBill.nextDueDate.formatted(.dateTime.month(.wide).day())).")
    }
}

enum BilLandarIntentError: LocalizedError {
    case invalidBill
    case billNotFound
    case inactiveBill
    case cancelledBill

    var errorDescription: String? {
        switch self {
        case .invalidBill: "Enter a name and an amount greater than zero."
        case .billNotFound: "That bill is no longer available in BilLandar."
        case .inactiveBill: "Only active bills can be marked as paid."
        case .cancelledBill: "Cancelled bills cannot be paused."
        }
    }
}

#if !WIDGET_EXTENSION
struct BilLandarAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MonthlySpendingIntent(),
            phrases: ["Check my monthly spending in \(.applicationName)", "How much did I spend in \(.applicationName) this month"],
            shortTitle: "Monthly Spending",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: AddBillIntent(),
            phrases: ["Add a bill in \(.applicationName)", "Create a subscription in \(.applicationName)"],
            shortTitle: "Add Bill",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: PauseBillIntent(),
            phrases: ["Pause a bill in \(.applicationName)"],
            shortTitle: "Pause Bill",
            systemImageName: "pause.circle.fill"
        )
        AppShortcut(
            intent: MarkBillPaidIntent(),
            phrases: ["Mark a bill paid in \(.applicationName)"],
            shortTitle: "Mark Paid",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
#endif
