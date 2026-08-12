import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now.startOfDay

    private let weekdaySymbols = Calendar.billandar.veryShortWeekdaySymbols
    private var calendarCellSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 58 : AppTheme.minimumTouchSize }
    private var calendarColumnSpacing: CGFloat { horizontalSizeClass == .regular ? 18 : 3 }
    private var calendarRowSpacing: CGFloat { horizontalSizeClass == .regular ? 14 : 12 }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: calendarCellSize), spacing: calendarColumnSpacing), count: 7)
    }

    private var selectedBills: [Bill] {
        bills.filter { $0.nextDueDate.isSameDay(as: selectedDate) && $0.status == .active }
    }

    private var activeBillsByDay: [Date: [Bill]] {
        Dictionary(grouping: bills.filter { $0.status == .active }) { $0.nextDueDate.startOfDay }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    calendarGrid
                    selectedDayCard
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 24)
                .billandarTabBarClearance()
                .frame(maxWidth: 1_100)
                .frame(maxWidth: .infinity)
            }
            .billandarCanvas()
            .billandarNavigationTitle("Calendar")
            .task {
                await exchangeRates.refreshIfNeeded()
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .billandarTouchTarget()
            .accessibilityLabel("Previous month")
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .billandarTouchTarget()
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var calendarGrid: some View {
        let billsByDay = activeBillsByDay
        LazyVGrid(columns: columns, spacing: calendarRowSpacing) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }

            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button { select(date) } label: {
                            VStack(spacing: 4) {
                                Text(date, format: .dateTime.day())
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(date.isSameDay(as: selectedDate) ? .white : AppTheme.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(
                                        width: dynamicTypeSize.isAccessibilitySize ? 52 : 36,
                                        height: dynamicTypeSize.isAccessibilitySize ? 52 : 36
                                    )
                                    .background(date.isSameDay(as: selectedDate) ? AppTheme.accent : .clear, in: Circle())
                                HStack(spacing: 2) {
                                    ForEach(Array((billsByDay[date.startOfDay] ?? []).prefix(3).enumerated()), id: \.offset) { index, _ in
                                        Circle()
                                            .fill([AppTheme.warning, AppTheme.danger, AppTheme.success][index])
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: calendarCellSize)
                        .buttonStyle(.plain)
                        .billandarTouchTarget()
                        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .accessibilityValue((billsByDay[date.startOfDay] ?? []).isEmpty ? "No bills due" : "\((billsByDay[date.startOfDay] ?? []).count) bills due")
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: calendarCellSize)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .billandarCard(padding: horizontalSizeClass == .regular ? 22 : 14)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 44 else { return }
                    moveMonth(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedDate, format: .dateTime.month(.wide).day().year())
                .font(.headline)

            if selectedBills.isEmpty {
                Text("No bills due")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(selectedBills.enumerated()), id: \.element.id) { index, bill in
                    NavigationLink {
                        BillDetailView(bill: bill)
                    } label: {
                        BillRow(bill: bill)
                    }
                    .buttonStyle(.plain)
                    if index < selectedBills.count - 1 { Divider().padding(.leading, 54) }
                }

                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        selectedDayTotal
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total").fontWeight(.semibold)
                        selectedDayTotal
                    }
                }
                .padding(.top, 4)
            }
        }
        .billandarCard()
    }

    @ViewBuilder
    private var selectedDayTotal: some View {
        if let total = exchangeRates.convertedTotal(for: selectedBills) {
            Text(total, format: .currency(code: exchangeRates.displayCurrency))
                .fontWeight(.bold)
        } else {
            Text("— \(exchangeRates.displayCurrency)")
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var monthCells: [Date?] {
        let calendar = Calendar.billandar
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = firstWeekday - calendar.firstWeekday
        let normalizedBlanks = leadingBlanks >= 0 ? leadingBlanks : leadingBlanks + 7
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        return Array(repeating: nil, count: normalizedBlanks) + dates.map(Optional.some)
    }

    private func moveMonth(by value: Int) {
        guard let month = Calendar.billandar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            displayedMonth = month
            selectedDate = Calendar.billandar.dateInterval(of: .month, for: month)?.start ?? month.startOfDay
        }
        feedbackCenter.selection()
    }

    private func select(_ date: Date) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            selectedDate = date
        }
        feedbackCenter.selection()
    }
}
