import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @State private var selectedHistoryMonth: Date?
    @State private var selectedCategoryTitle: String?

    private var activeBills: [Bill] { bills.filter { $0.status == .active } }

    private var historyStartDate: Date {
        Calendar.billandar.date(byAdding: .month, value: -5, to: Date.now.startOfDay) ?? Date.now
    }

    private var historicalPayments: [PaymentRecord] {
        payments.filter { $0.status == .paid && $0.paidAt >= historyStartDate }
    }

    private var historyLoadKey: String {
        let currencies = Set(historicalPayments.map(\.currencyCode)).sorted().joined(separator: ",")
        let latestPayment = historicalPayments.map(\.paidAt.timeIntervalSince1970).max() ?? 0
        return "\(exchangeRates.displayCurrency)|\(currencies)|\(historicalPayments.count)|\(latestPayment)"
    }

    private var monthlySpending: [(month: Date, amount: Double)] {
        let converted = historicalPayments.compactMap { payment -> (Date, Double)? in
            guard let month = Calendar.billandar.dateInterval(of: .month, for: payment.paidAt)?.start,
                  let amount = exchangeRates.historicalConvert(
                    payment.amount,
                    from: payment.currencyCode,
                    at: payment.paidAt
                  ) else { return nil }
            return (month, amount)
        }
        let grouped = Dictionary(grouping: converted, by: \.0)
        return grouped.map { month, values in
            (month, values.reduce(0) { $0 + $1.1 })
        }
        .sorted { $0.month < $1.month }
    }

    private var selectedHistoryItem: (month: Date, amount: Double)? {
        guard let selectedHistoryMonth else { return nil }
        return monthlySpending.min {
            abs($0.month.timeIntervalSince(selectedHistoryMonth))
                < abs($1.month.timeIntervalSince(selectedHistoryMonth))
        }
    }

    private var selectedCategoryItem: (category: BillCategory, amount: Double)? {
        guard let selectedCategoryTitle else { return nil }
        return categoryData.first { $0.category.title == selectedCategoryTitle }
    }

    private var hasIncompleteHistory: Bool {
        monthlySpending.isEmpty ? !historicalPayments.isEmpty : monthlySpending.count > 0 &&
            historicalPayments.contains {
                exchangeRates.historicalConvert($0.amount, from: $0.currencyCode, at: $0.paidAt) == nil
            }
    }

    private var monthlyTotal: Double? {
        exchangeRates.convertedTotal(for: activeBills) { $0.monthlyEquivalentAmount }
    }

    private var categoryData: [(category: BillCategory, amount: Double)] {
        BillCategory.allCases.compactMap { category in
            let categoryBills = activeBills.filter { $0.category == category }
            guard !categoryBills.isEmpty,
                  let total = exchangeRates.convertedTotal(for: categoryBills, amount: { $0.monthlyEquivalentAmount }) else {
                return nil
            }
            return (category, total)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var currencyData: [(code: String, amount: Double, billCount: Int)] {
        let groups = Dictionary(grouping: activeBills, by: \.currencyCode)
        return groups.map { code, bills in
            (code, bills.reduce(0) { $0 + $1.monthlyEquivalentAmount }, bills.count)
        }
        .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    spendingHistoryCard
                    summaryCard
                    originalCurrencyCard
                    categoryCard
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 24)
                .billandarTabBarClearance()
            }
            .billandarCanvas()
            .refreshable {
                await exchangeRates.refresh()
                exchangeRates.hasUsableRates ? feedbackCenter.success() : feedbackCenter.warning()
            }
            .billandarNavigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await exchangeRates.refresh()
                            exchangeRates.hasUsableRates ? feedbackCenter.success() : feedbackCenter.warning()
                        }
                    } label: {
                        if exchangeRates.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17))
                        }
                    }
                    .accessibilityLabel("Refresh exchange rates")
                }
            }
            .task(id: historyLoadKey) {
                await exchangeRates.refreshIfNeeded()
                let currencies = Set(historicalPayments.map(\.currencyCode))
                await exchangeRates.loadHistoricalRates(
                    from: Calendar.billandar.date(byAdding: .day, value: -7, to: historyStartDate) ?? historyStartDate,
                    to: .now,
                    currencies: currencies
                )
            }
        }
    }

    private var spendingHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Actual payment history").font(.headline)
                    Text("Converted using each payment date's reference rate")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if exchangeRates.isLoadingHistory { ProgressView() }
            }

            if exchangeRates.isLoadingHistory {
                VStack(spacing: 12) {
                    BilLandarSkeleton(height: 138, cornerRadius: 14)
                    HStack {
                        BilLandarSkeleton(width: 54, height: 10)
                        Spacer()
                        BilLandarSkeleton(width: 54, height: 10)
                    }
                }
            } else if monthlySpending.isEmpty {
                Text(historicalPayments.isEmpty ? "No confirmed payments yet." : "Historical rates are unavailable for these payments.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                Chart(monthlySpending, id: \.month) { item in
                    AreaMark(
                        x: .value("Month", item.month),
                        y: .value("Paid", item.amount)
                    )
                    .foregroundStyle(AppTheme.accent.opacity(0.16))
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Paid", item.amount)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .accessibilityLabel(item.month.formatted(.dateTime.month(.wide).year()))
                    .accessibilityValue(item.amount.formatted(.currency(code: exchangeRates.displayCurrency)))
                    PointMark(
                        x: .value("Month", item.month),
                        y: .value("Paid", item.amount)
                    )
                    .foregroundStyle(AppTheme.accent)

                    if let selectedHistoryItem,
                       selectedHistoryItem.month == item.month {
                        RuleMark(x: .value("Selected month", item.month))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        PointMark(
                            x: .value("Selected month", item.month),
                            y: .value("Selected amount", item.amount)
                        )
                        .symbolSize(70)
                        .foregroundStyle(AppTheme.accent)
                        .annotation(position: .top, spacing: 8) {
                            VStack(spacing: 2) {
                                Text(item.month, format: .dateTime.month(.abbreviated))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(item.amount, format: .currency(code: exchangeRates.displayCurrency))
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartXSelection(value: $selectedHistoryMonth)
                .onChange(of: selectedHistoryItem?.month) { _, newValue in
                    if newValue != nil { feedbackCenter.selection() }
                }
                .frame(height: 170)
                .accessibilityLabel("Actual monthly payment history")
                .accessibilityHint("Swipe across the chart to inspect each month")

                if hasIncompleteHistory || exchangeRates.historicalErrorMessage != nil {
                    Label("Some payments were excluded because a historical rate was unavailable.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                }
            }
        }
        .billandarCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly recurring total")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            if let monthlyTotal {
                Text(monthlyTotal, format: .currency(code: exchangeRates.displayCurrency))
                    .font(.title.bold())
            } else {
                Text("—")
                    .font(.title.bold())
            }

            HStack(spacing: 5) {
                Image(systemName: exchangeRates.hasUsableRates ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(exchangeRates.dataStatusText)
            }
            .font(.caption)
            .foregroundStyle(exchangeRates.hasUsableRates ? AppTheme.success : AppTheme.warning)

            if !categoryData.isEmpty {
                Chart(categoryData, id: \.category) { item in
                    BarMark(
                        x: .value("Category", item.category.title),
                        y: .value("Monthly amount", item.amount)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                    .cornerRadius(5)
                    .accessibilityLabel(item.category.title)
                    .accessibilityValue(item.amount.formatted(.currency(code: exchangeRates.displayCurrency)))
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let title = value.as(String.self) {
                                Text(String(title.prefix(4)))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedCategoryTitle)
                .onChange(of: selectedCategoryTitle) { _, newValue in
                    if newValue != nil { feedbackCenter.selection() }
                }
                .frame(height: 150)
                .padding(.top, 8)
                .accessibilityLabel("Monthly recurring total by category")

                if let selectedCategoryItem {
                    HStack {
                        Label(selectedCategoryItem.category.title, systemImage: selectedCategoryItem.category.symbolName)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(selectedCategoryItem.amount, format: .currency(code: exchangeRates.displayCurrency))
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .billandarCard()
    }

    private var originalCurrencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Original currencies").font(.headline)
                Spacer()
                Text("Monthly equivalent")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(currencyData, id: \.code) { item in
                HStack(spacing: 12) {
                    Text(Currency.currency(for: item.code).symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.code).font(.subheadline.weight(.semibold))
                        Text("\(item.billCount) \(item.billCount == 1 ? "bill" : "bills")")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()
                    Text(item.amount, format: .currency(code: item.code))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .billandarCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("By category").font(.headline)
                Spacer()
                Text("In \(exchangeRates.displayCurrency)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }

            if let monthlyTotal, !categoryData.isEmpty {
                ForEach(categoryData, id: \.category) { item in
                    CategoryProgressRow(
                        category: item.category,
                        amount: item.amount,
                        total: monthlyTotal,
                        currencyCode: exchangeRates.displayCurrency
                    )
                }
            } else {
                Text("Refresh rates to compare categories across currencies.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        }
        .billandarCard()
    }
}

private struct CategoryProgressRow: View {
    let category: BillCategory
    let amount: Double
    let total: Double
    let currencyCode: String

    private var ratio: Double { total > 0 ? amount / total : 0 }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(category.title).font(.subheadline)
                    Spacer()
                    Text(amount, format: .currency(code: currencyCode))
                        .font(.subheadline.weight(.semibold))
                }
                GeometryReader { proxy in
                    Capsule()
                        .fill(AppTheme.divider)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.accent)
                                .frame(width: proxy.size.width * ratio)
                        }
                }
                .frame(height: 5)
            }
        }
    }
}
