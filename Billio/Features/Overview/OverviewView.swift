import Charts
import SwiftData
import SwiftUI

struct OverviewView: View {
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @State private var showingAddBill = false

    private var activeBills: [Bill] { bills.filter { $0.status == .active } }

    private var upcomingBills: [Bill] {
        let endDate = Calendar.billio.date(byAdding: .day, value: 7, to: .now) ?? .now
        return activeBills.filter { $0.nextDueDate <= endDate }
    }

    private var groupedBills: [(date: Date, bills: [Bill])] {
        let groups = Dictionary(grouping: activeBills.prefix(6)) { $0.nextDueDate.startOfDay }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    private var insights: [BillInsight] {
        InsightEngine.generate(bills: bills, payments: payments)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    WeekStripView(bills: activeBills)
                    insightSection

                    ForEach(groupedBills, id: \.date) { group in
                        billGroup(date: group.date, bills: group.bills)
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 24)
            }
            .billioCanvas()
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("Add bill")
                }
            }
            .sheet(isPresented: $showingAddBill) {
                AddBillView()
            }
            .task {
                await exchangeRates.refreshIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var insightSection: some View {
        if let firstInsight = insights.first {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smart insights")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    NavigationLink("View all") {
                        InsightsView()
                    }
                    .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 4)

                NavigationLink {
                    InsightsView()
                } label: {
                    InsightCard(insight: firstInsight, showsChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Upcoming bills")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                if let total = exchangeRates.convertedTotal(for: upcomingBills) {
                    Text(total, format: .currency(code: exchangeRates.displayCurrency))
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                } else {
                    Text("—")
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text("Next 7 days · \(exchangeRates.displayCurrency)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(exchangeRates.dataStatusText)
                    .font(.caption2)
                    .foregroundStyle(exchangeRates.errorMessage == nil ? AppTheme.textSecondary : AppTheme.warning)
                    .lineLimit(1)
            }

            if categoryTotals.isEmpty && exchangeRates.isLoading {
                ProgressView()
                    .frame(width: 76, height: 76)
            } else {
                Chart(categoryTotals.prefix(3), id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.68),
                        angularInset: 1.5
                    )
                    .foregroundStyle(categoryColor(item.category))
                    .cornerRadius(2)
                }
                .frame(width: 76, height: 76)
                .chartLegend(.hidden)
            }
        }
        .billioCard()
    }

    private var categoryTotals: [(category: BillCategory, amount: Double)] {
        BillCategory.allCases.compactMap { category in
            let categoryBills = upcomingBills.filter { $0.category == category }
            guard let amount = exchangeRates.convertedTotal(for: categoryBills) else { return nil }
            return amount > 0 ? (category, amount) : nil
        }
    }

    private func categoryColor(_ category: BillCategory) -> Color {
        switch category {
        case .entertainment: AppTheme.accent
        case .productivity: Color(hex: "4E89D8")
        case .storage: Color(hex: "38B89A")
        case .finance: AppTheme.danger
        case .utilities: AppTheme.warning
        case .other: Color(hex: "9A96B2")
        }
    }

    private func billGroup(date: Date, bills: [Bill]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groupTitle(for: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(bills.enumerated()), id: \.element.id) { index, bill in
                    NavigationLink {
                        BillDetailView(bill: bill)
                    } label: {
                        BillRow(bill: bill, showsDueBadge: true)
                    }
                    .buttonStyle(.plain)

                    if index < bills.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .billioCard(padding: 12)
        }
    }

    private func groupTitle(for date: Date) -> String {
        if Calendar.billio.isDateInToday(date) { return "Today" }
        if Calendar.billio.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct WeekStripView: View {
    let bills: [Bill]

    private var days: [Date] {
        (0..<7).compactMap { Calendar.billio.date(byAdding: .day, value: $0, to: .now.startOfDay) }
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { date in
                VStack(spacing: 7) {
                    Text(date, format: .dateTime.weekday(.narrow))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(date, format: .dateTime.day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(date.isSameDay(as: .now) ? .white : AppTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(date.isSameDay(as: .now) ? AppTheme.accent : .clear, in: Circle())
                    Circle()
                        .fill(bills.contains { $0.nextDueDate.isSameDay(as: date) } ? AppTheme.warning : .clear)
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .billioCard(padding: 12)
    }
}
