import SwiftData
import SwiftUI
import WidgetKit

struct BilLandarWidgetEntry: TimelineEntry {
    let date: Date
    let nextBills: [BilLandarSystemBill]
    let monthlyTotal: BilLandarSystemTotal
    let loadError: String?

    static let placeholder = BilLandarWidgetEntry(
        date: .now,
        nextBills: [
            BilLandarSystemBill(
                id: UUID(),
                name: "Streamly",
                subtitle: "Monthly Plan",
                amount: 15.49,
                currencyCode: "USD",
                nextDueDate: Calendar.billandar.date(byAdding: .day, value: 1, to: .now) ?? .now,
                status: .active,
                symbolName: "play.fill",
                brandColorHex: "111111"
            ),
            BilLandarSystemBill(
                id: UUID(),
                name: "CloudNest+",
                subtitle: "200 GB Storage",
                amount: 2.99,
                currencyCode: "USD",
                nextDueDate: Calendar.billandar.date(byAdding: .day, value: 3, to: .now) ?? .now,
                status: .active,
                symbolName: "icloud.fill",
                brandColorHex: "46A8F0"
            )
        ],
        monthlyTotal: BilLandarSystemTotal(amount: 86.64, currencyCode: "USD", originalCurrencyBreakdown: [:]),
        loadError: nil
    )
}

struct BilLandarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BilLandarWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BilLandarWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in completion(loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BilLandarWidgetEntry>) -> Void) {
        Task { @MainActor in
            let entry = loadEntry()
            let nextRefresh = Calendar.billandar.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func loadEntry() -> BilLandarWidgetEntry {
        do {
            let container = try BilLandarSystemData.makeContainer()
            let context = ModelContext(container)
            return BilLandarWidgetEntry(
                date: .now,
                nextBills: try BilLandarSystemData.nextBills(limit: 6, in: context),
                monthlyTotal: try BilLandarSystemData.monthlySpending(in: context),
                loadError: nil
            )
        } catch {
            return BilLandarWidgetEntry(
                date: .now,
                nextBills: [],
                monthlyTotal: BilLandarSystemTotal(
                    amount: nil,
                    currencyCode: BilLandarSystemData.displayCurrency,
                    originalCurrencyBreakdown: [:]
                ),
                loadError: String(localized: "Open BilLandar to sync", locale: BilLandarSharedStore.appLocale)
            )
        }
    }
}
