import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query private var bills: [Bill]
    @Query private var payments: [PaymentRecord]

    private var insights: [BillInsight] {
        InsightEngine.generate(bills: bills, payments: payments)
    }

    var body: some View {
        ScrollView {
            if insights.isEmpty {
                EmptyStateView(
                    title: "Everything looks healthy",
                    message: "Billio will watch for price changes, trial endings, duplicate services, and payment issues.",
                    symbolName: "checkmark.shield.fill"
                )
                .frame(minHeight: 420)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(insights) { insight in
                        if let bill = bill(for: insight) {
                            NavigationLink {
                                BillDetailView(bill: bill)
                            } label: {
                                InsightCard(insight: insight, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            InsightCard(insight: insight)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 24)
            }
        }
        .billioCanvas()
        .navigationTitle("Smart Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bill(for insight: BillInsight) -> Bill? {
        guard let firstID = insight.billIDs.first else { return nil }
        return bills.first { $0.id == firstID }
    }
}

struct InsightCard: View {
    let insight: BillInsight
    var showsChevron = false

    private var color: Color {
        switch insight.severity {
        case .info: Color(hex: "4E89D8")
        case .warning: AppTheme.warning
        case .critical: AppTheme.danger
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .padding(.top, 10)
            }
        }
        .billioCard(padding: 14)
    }
}
