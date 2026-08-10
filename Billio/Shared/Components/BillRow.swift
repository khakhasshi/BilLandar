import SwiftUI

struct BillRow: View {
    let bill: Bill
    var showsDueBadge = false

    var body: some View {
        HStack(spacing: 12) {
            BillIcon(bill: bill)

            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(bill.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
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
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var dueBadge: some View {
        let days = Calendar.billio.dateComponents(
            [.day],
            from: Date.now.startOfDay,
            to: bill.nextDueDate.startOfDay
        ).day ?? 0
        let title = days <= 0 ? "Due today" : days == 1 ? "Due tomorrow" : "In \(days) days"

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
