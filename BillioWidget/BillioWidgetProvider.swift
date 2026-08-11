import SwiftData
import SwiftUI
import WidgetKit

struct BillioWidgetEntry: TimelineEntry {
    let date: Date
    let nextBills: [BillioSystemBill]
    let monthlyTotal: BillioSystemTotal
    let loadError: String?

    static let placeholder = BillioWidgetEntry(
        date: .now,
        nextBills: [
            BillioSystemBill(
                id: UUID(),
                name: "Netflix",
                subtitle: "Monthly Plan",
                amount: 15.49,
                currencyCode: "USD",
                nextDueDate: Calendar.billio.date(byAdding: .day, value: 1, to: .now) ?? .now,
                status: .active,
                symbolName: "play.fill",
                brandColorHex: "111111"
            ),
            BillioSystemBill(
                id: UUID(),
                name: "iCloud+",
                subtitle: "200 GB Storage",
                amount: 2.99,
                currencyCode: "USD",
                nextDueDate: Calendar.billio.date(byAdding: .day, value: 3, to: .now) ?? .now,
                status: .active,
                symbolName: "icloud.fill",
                brandColorHex: "46A8F0"
            )
        ],
        monthlyTotal: BillioSystemTotal(amount: 86.64, currencyCode: "USD", originalCurrencyBreakdown: [:]),
        loadError: nil
    )
}

struct BillioWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BillioWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BillioWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in completion(loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BillioWidgetEntry>) -> Void) {
        Task { @MainActor in
            let entry = loadEntry()
            let nextRefresh = Calendar.billio.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func loadEntry() -> BillioWidgetEntry {
        do {
            let container = try BillioSystemData.makeContainer()
            let context = ModelContext(container)
            return BillioWidgetEntry(
                date: .now,
                nextBills: try BillioSystemData.nextBills(limit: 6, in: context),
                monthlyTotal: try BillioSystemData.monthlySpending(in: context),
                loadError: nil
            )
        } catch {
            return BillioWidgetEntry(
                date: .now,
                nextBills: [],
                monthlyTotal: BillioSystemTotal(
                    amount: nil,
                    currencyCode: BillioSystemData.displayCurrency,
                    originalCurrencyBreakdown: [:]
                ),
                loadError: String(localized: "Open Billio to sync", locale: BillioSharedStore.appLocale)
            )
        }
    }
}
