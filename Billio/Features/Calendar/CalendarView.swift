import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now.startOfDay

    private let weekdaySymbols = Calendar.billio.veryShortWeekdaySymbols
    private var calendarCellSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 58 : AppTheme.minimumTouchSize }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(calendarCellSize), spacing: 3), count: 7)
    }

    private var selectedBills: [Bill] {
        bills.filter { $0.nextDueDate.isSameDay(as: selectedDate) && $0.status == .active }
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
                .billioTabBarClearance()
            }
            .billioCanvas()
            .billioNavigationTitle("Calendar")
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
            .billioTouchTarget()
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
            .billioTouchTarget()
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 8)
    }

    private var calendarGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
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
                                    ForEach(Array(dueBills(on: date).prefix(3).enumerated()), id: \.offset) { index, _ in
                                        Circle()
                                            .fill([AppTheme.warning, AppTheme.danger, AppTheme.success][index])
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        .billioTouchTarget()
                        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .accessibilityValue(dueBills(on: date).isEmpty ? "No bills due" : "\(dueBills(on: date).count) bills due")
                    } else {
                        Color.clear.frame(height: AppTheme.minimumTouchSize)
                    }
                }
            }
            .frame(width: 7 * calendarCellSize + 18)
        }
        .billioCard(padding: 14)
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
        .billioCard()
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
        let calendar = Calendar.billio
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

    private func dueBills(on date: Date) -> [Bill] {
        bills.filter { $0.nextDueDate.isSameDay(as: date) && $0.status == .active }
    }

    private func moveMonth(by value: Int) {
        guard let month = Calendar.billio.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            displayedMonth = month
            selectedDate = Calendar.billio.dateInterval(of: .month, for: month)?.start ?? month.startOfDay
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
