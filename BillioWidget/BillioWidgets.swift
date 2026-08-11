import AppIntents
import SwiftUI
import WidgetKit

private enum WidgetPalette {
    static let accent = Color(red: 0.45, green: 0.34, blue: 0.96)
    static let accentSoft = Color(red: 0.45, green: 0.34, blue: 0.96).opacity(0.13)
    static let danger = Color(red: 0.88, green: 0.25, blue: 0.38)
}

struct NextPaymentWidget: Widget {
    let kind = "Billio.NextPayment"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BillioWidgetProvider()) { entry in
            NextPaymentWidgetView(entry: entry)
                .environment(\.locale, BillioSharedStore.appLocale)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        }
        .configurationDisplayName("Next Payment")
        .description("See your next renewal and mark it as paid without opening Billio.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MonthlySpendingWidget: Widget {
    let kind = "Billio.MonthlySpending"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BillioWidgetProvider()) { entry in
            MonthlySpendingWidgetView(entry: entry)
                .environment(\.locale, BillioSharedStore.appLocale)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        }
        .configurationDisplayName("Monthly Spending")
        .description("Track confirmed subscription payments recorded this month.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UpcomingBillsWidget: Widget {
    let kind = "Billio.UpcomingBills"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BillioWidgetProvider()) { entry in
            UpcomingBillsWidgetView(entry: entry)
                .environment(\.locale, BillioSharedStore.appLocale)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        }
        .configurationDisplayName("Upcoming Bills")
        .description("A compact renewal queue with direct payment confirmation.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct NextPaymentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BillioWidgetEntry

    var body: some View {
        if let bill = entry.nextBills.first {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 8) {
                    widgetHeader("Next payment", symbol: "calendar.badge.clock")
                    Spacer(minLength: 0)
                    billIcon(bill, size: 38)
                    Text(bill.name).font(.headline).lineLimit(1)
                    Text(bill.amount, format: .currency(code: bill.currencyCode))
                        .font(.title3.bold())
                        .privacySensitive()
                    paymentButton(for: bill, compact: true)
                }
            } else {
                HStack(spacing: 14) {
                    billIcon(bill, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        widgetHeader("Next payment", symbol: "calendar.badge.clock")
                        Text(bill.name).font(.headline).lineLimit(1)
                        Text(String(localized: String.LocalizationValue(bill.subtitle), locale: BillioSharedStore.appLocale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(dueText(for: bill.nextDueDate)).font(.caption.weight(.medium)).foregroundStyle(WidgetPalette.danger)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 10) {
                        Text(bill.amount, format: .currency(code: bill.currencyCode))
                            .font(.title3.bold())
                            .privacySensitive()
                        paymentButton(for: bill, compact: false)
                    }
                }
            }
        } else {
            widgetEmptyState(
                message: entry.loadError
                    ?? String(localized: "No upcoming bills", locale: BillioSharedStore.appLocale)
            )
        }
    }
}

private struct MonthlySpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BillioWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader("This month", symbol: "chart.pie.fill")
            Spacer(minLength: 0)
            Text(entry.monthlyTotal.formatted)
                .font(family == .systemSmall ? .title2.bold() : .largeTitle.bold())
                .minimumScaleFactor(0.65)
                .lineLimit(family == .systemSmall ? 2 : 1)
                .privacySensitive()
            Text(
                entry.monthlyTotal.amount == nil
                    ? String(localized: "Shown by original currency", locale: BillioSharedStore.appLocale)
                    : String(localized: "Confirmed payments", locale: BillioSharedStore.appLocale)
            )
                .font(.caption)
                .foregroundStyle(.secondary)
            if family == .systemMedium {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                    Text(String(localized: "Only payments marked paid are included", locale: BillioSharedStore.appLocale))
                }
                .font(.caption2)
                .foregroundStyle(WidgetPalette.accent)
            }
        }
    }
}

private struct UpcomingBillsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BillioWidgetEntry

    private var visibleBills: ArraySlice<BillioSystemBill> {
        entry.nextBills.prefix(family == .systemLarge ? 5 : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader("Upcoming bills", symbol: "list.bullet.clipboard.fill")
            if visibleBills.isEmpty {
                Spacer()
                widgetEmptyState(
                    message: entry.loadError
                        ?? String(localized: "Nothing due soon", locale: BillioSharedStore.appLocale)
                )
                Spacer()
            } else {
                ForEach(visibleBills) { bill in
                    HStack(spacing: 9) {
                        billIcon(bill, size: family == .systemLarge ? 34 : 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(dueText(for: bill.nextDueDate)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 3)
                        Text(bill.amount, format: .currency(code: bill.currencyCode))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .privacySensitive()
                        paymentButton(for: bill, compact: true)
                    }
                    if bill.id != visibleBills.last?.id { Divider() }
                }
            }
        }
    }
}

@ViewBuilder
private func widgetHeader(_ title: LocalizedStringKey, symbol: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: symbol).foregroundStyle(WidgetPalette.accent)
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}

@ViewBuilder
private func billIcon(_ bill: BillioSystemBill, size: CGFloat) -> some View {
    Image(systemName: bill.symbolName)
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(Color(hex: bill.brandColorHex).gradient, in: RoundedRectangle(cornerRadius: size * 0.27))
}

@ViewBuilder
private func paymentButton(for bill: BillioSystemBill, compact: Bool) -> some View {
    let entity = BillEntity(
        id: bill.id,
        name: bill.name,
        amount: bill.amount,
        currencyCode: bill.currencyCode,
        nextDueDate: bill.nextDueDate
    )
    Button(intent: MarkBillPaidIntent(bill: entity)) {
        if compact {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(WidgetPalette.accent)
                .accessibilityLabel(
                    String(
                        format: String(localized: "Mark %@ paid", locale: BillioSharedStore.appLocale),
                        bill.name
                    )
                )
        } else {
            Label("Paid", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(WidgetPalette.accent)
                .background(WidgetPalette.accentSoft, in: Capsule())
        }
    }
    .buttonStyle(.plain)
}

@ViewBuilder
private func widgetEmptyState(message: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(WidgetPalette.accent)
        Text(message).font(.caption).foregroundStyle(.secondary)
    }
}

private func dueText(for date: Date) -> String {
    if Calendar.billio.isDateInToday(date) {
        return String(localized: "Due today", locale: BillioSharedStore.appLocale)
    }
    if Calendar.billio.isDateInTomorrow(date) {
        return String(localized: "Due tomorrow", locale: BillioSharedStore.appLocale)
    }
    return String(localized: "Due", locale: BillioSharedStore.appLocale)
        + " " + date.formatted(.dateTime.month(.abbreviated).day())
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double(value >> 16 & 0xFF) / 255,
            green: Double(value >> 8 & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
