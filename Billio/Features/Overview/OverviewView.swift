import Charts
import SwiftData
import SwiftUI

struct OverviewView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @State private var showingAddBill = false
    @State private var selectedWeekDate: Date?

    private var activeBills: [Bill] { bills.filter { $0.status == .active } }

    private var upcomingBills: [Bill] {
        let endDate = Calendar.billio.date(byAdding: .day, value: 7, to: .now) ?? .now
        return activeBills.filter { $0.nextDueDate <= endDate }
    }

    private var groupedBills: [(date: Date, bills: [Bill])] {
        let candidates: [Bill]
        if let selectedWeekDate {
            candidates = activeBills.filter { $0.nextDueDate.isSameDay(as: selectedWeekDate) }
        } else {
            candidates = Array(activeBills.prefix(6))
        }
        let groups = Dictionary(grouping: candidates) { $0.nextDueDate.startOfDay }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    private var notificationBadgeCount: Int {
        min(99, upcomingBills.count + insights.filter { $0.kind == .paymentIssue || $0.kind == .trialEnding }.count)
    }

    private var insights: [BillInsight] {
        InsightEngine.generate(bills: bills, payments: payments)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    WeekStripView(bills: activeBills, selectedDate: selectedWeekDate) { date in
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                            selectedWeekDate = selectedWeekDate?.isSameDay(as: date) == true ? nil : date.startOfDay
                        }
                        feedbackCenter.selection()
                    }
                    insightSection

                    if groupedBills.isEmpty, let selectedWeekDate {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title2)
                                .foregroundStyle(AppTheme.success)
                            Text("No bills due \(selectedWeekDate.formatted(.dateTime.weekday(.wide)))")
                                .font(.subheadline.weight(.semibold))
                            Button("Show all upcoming") { self.selectedWeekDate = nil }
                                .font(.caption.weight(.semibold))
                                .billioTouchTarget()
                        }
                        .frame(maxWidth: .infinity)
                        .billioCard()
                    } else {
                        ForEach(groupedBills, id: \.date) { group in
                            billGroup(date: group.date, bills: group.bills)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 24)
                .billioTabBarClearance()
            }
            .billioCanvas()
            .refreshable {
                await exchangeRates.refresh()
                exchangeRates.hasUsableRates ? feedbackCenter.success() : feedbackCenter.warning()
            }
            .billioNavigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 17))
                                .billioTouchTarget()
                            if notificationBadgeCount > 0 {
                                Text(notificationBadgeCount > 9 ? "9+" : "\(notificationBadgeCount)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(AppTheme.danger, in: Capsule())
                                    .offset(x: 4, y: -1)
                            }
                        }
                    }
                    .accessibilityLabel("Notifications, \(notificationBadgeCount) items")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBill = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
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
                ViewThatFits(in: .horizontal) {
                    HStack {
                        insightSectionTitle
                        Spacer()
                        insightViewAllLink
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        insightSectionTitle
                        insightViewAllLink
                    }
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
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryText
                        HStack(alignment: .center, spacing: 18) {
                            summaryChart
                            categoryLegend
                        }
                    }
                } else {
                    HStack(spacing: 18) { summaryText; summaryChart }
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                categoryLegend
            }
        }
        .billioCard()
    }

    private var insightSectionTitle: some View {
        Text("Smart insights")
            .font(.subheadline.weight(.semibold))
    }

    private var insightViewAllLink: some View {
        NavigationLink("View all") {
            InsightsView()
        }
        .font(.caption.weight(.medium))
        .billioTouchTarget()
    }

    @ViewBuilder
    private var categoryLegend: some View {
        if !categoryTotals.isEmpty {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        categoryLegendItems
                    }
                } else {
                    HStack(spacing: 12) {
                        categoryLegendItems
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Top upcoming categories: \(categoryTotals.prefix(3).map { $0.category.title }.joined(separator: ", "))")
        }
    }

    @ViewBuilder
    private var categoryLegendItems: some View {
        ForEach(Array(categoryTotals.prefix(3)), id: \.category) { item in
            HStack(spacing: 5) {
                Circle().fill(categoryColor(item.category)).frame(width: 7, height: 7)
                Text(item.category.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var summaryText: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Upcoming bills")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                if exchangeRates.isLoading && !exchangeRates.hasUsableRates {
                    BillioSkeleton(width: 154, height: 34, cornerRadius: 9)
                } else if let total = exchangeRates.convertedTotal(for: upcomingBills) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryChart: some View {
        Group {
            if categoryTotals.isEmpty && exchangeRates.isLoading {
                BillioSkeleton(width: 76, height: 76, cornerRadius: 38)
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
                .accessibilityLabel("Upcoming bills by category")
            }
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bills: [Bill]
    let selectedDate: Date?
    let onSelect: (Date) -> Void

    private var days: [Date] {
        (0..<7).compactMap { Calendar.billio.date(byAdding: .day, value: $0, to: .now.startOfDay) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { date in
                Button { onSelect(date) } label: {
                    VStack(spacing: 7) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(date, format: .dateTime.day())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedDate?.isSameDay(as: date) == true ? .white : AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(
                                width: dynamicTypeSize.isAccessibilitySize ? 54 : 34,
                                height: dynamicTypeSize.isAccessibilitySize ? 54 : 34
                            )
                            .background(
                                selectedDate?.isSameDay(as: date) == true ? AppTheme.accent : .clear,
                                in: Circle()
                            )
                            .overlay {
                                if date.isSameDay(as: .now), selectedDate?.isSameDay(as: date) != true {
                                    Circle().stroke(AppTheme.accent, lineWidth: 1.5)
                                }
                            }
                        Circle()
                            .fill(bills.contains { $0.nextDueDate.isSameDay(as: date) } ? AppTheme.warning : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 68 : AppTheme.minimumTouchSize)
                }
                .buttonStyle(.plain)
                .billioTouchTarget()
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .accessibilityValue(bills.contains { $0.nextDueDate.isSameDay(as: date) } ? "Has bills due" : "No bills due")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .billioCard(padding: 12)
    }
}
