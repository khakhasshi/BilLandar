import SwiftData
import SwiftUI
import WidgetKit

struct BillowWidgetEntry: TimelineEntry {
    let date: Date
    let nextBills: [BillowSystemBill]
    let monthlyTotal: BillowSystemTotal
    let loadError: String?

    static let placeholder = BillowWidgetEntry(
        date: .now,
        nextBills: [
            BillowSystemBill(
                id: UUID(),
                name: "Streamly",
                subtitle: "Monthly Plan",
                amount: 15.49,
                currencyCode: "USD",
                nextDueDate: Calendar.billow.date(byAdding: .day, value: 1, to: .now) ?? .now,
                status: .active,
                symbolName: "play.fill",
                brandColorHex: "111111"
            ),
            BillowSystemBill(
                id: UUID(),
                name: "CloudNest+",
                subtitle: "200 GB Storage",
                amount: 2.99,
                currencyCode: "USD",
                nextDueDate: Calendar.billow.date(byAdding: .day, value: 3, to: .now) ?? .now,
                status: .active,
                symbolName: "icloud.fill",
                brandColorHex: "46A8F0"
            )
        ],
        monthlyTotal: BillowSystemTotal(amount: 86.64, currencyCode: "USD", originalCurrencyBreakdown: [:]),
        loadError: nil
    )
}

struct BillowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BillowWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BillowWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in completion(loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BillowWidgetEntry>) -> Void) {
        Task { @MainActor in
            let entry = loadEntry()
            let nextRefresh = Calendar.billow.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func loadEntry() -> BillowWidgetEntry {
        do {
            let container = try BillowSystemData.makeContainer()
            let context = ModelContext(container)
            return BillowWidgetEntry(
                date: .now,
                nextBills: try BillowSystemData.nextBills(limit: 6, in: context),
                monthlyTotal: try BillowSystemData.monthlySpending(in: context),
                loadError: nil
            )
        } catch {
            return BillowWidgetEntry(
                date: .now,
                nextBills: [],
                monthlyTotal: BillowSystemTotal(
                    amount: nil,
                    currencyCode: BillowSystemData.displayCurrency,
                    originalCurrencyBreakdown: [:]
                ),
                loadError: String(localized: "Open Billow to sync", locale: BillowSharedStore.appLocale)
            )
        }
    }
}
