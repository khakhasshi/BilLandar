import SwiftUI

struct BillRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bill: Bill
    var showsDueBadge = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    identity
                    amountAndDue
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 12) {
                    identity
                    Spacer(minLength: 8)
                    amountAndDue
                }
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        HStack(spacing: 12) {
            BillIcon(bill: bill)

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(bill.localizedSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var amountAndDue: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(bill.amount, format: .currency(code: bill.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if showsDueBadge {
                dueBadge
            } else {
                Text(bill.nextDueDate, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var dueBadge: some View {
        let days = Calendar.billow.dateComponents(
            [.day],
            from: Date.now.startOfDay,
            to: bill.nextDueDate.startOfDay
        ).day ?? 0
        let title: String
        if days <= 0 {
            title = String(localized: "Due today", locale: BillowSharedStore.appLocale)
        } else if days == 1 {
            title = String(localized: "Due tomorrow", locale: BillowSharedStore.appLocale)
        } else {
            title = String(
                format: String(localized: "In %lld days", locale: BillowSharedStore.appLocale),
                days
            )
        }

        return Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(days <= 1 ? AppTheme.danger : AppTheme.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (days <= 1 ? AppTheme.danger : AppTheme.warning).opacity(0.12),
                in: Capsule()
            )
    }
}
