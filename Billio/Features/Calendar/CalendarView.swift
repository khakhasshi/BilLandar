import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now.startOfDay

    private let weekdaySymbols = Calendar.billio.veryShortWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

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
            }
            .billioCanvas()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
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
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button { moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 8)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date {
                    Button { selectedDate = date } label: {
                        VStack(spacing: 4) {
                            Text(date, format: .dateTime.day())
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(date.isSameDay(as: selectedDate) ? .white : AppTheme.textPrimary)
                                .frame(width: 34, height: 34)
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
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
        .billioCard(padding: 14)
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
                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    if let total = exchangeRates.convertedTotal(for: selectedBills) {
                        Text(total, format: .currency(code: exchangeRates.displayCurrency))
                            .fontWeight(.bold)
                    } else {
                        Text("— \(exchangeRates.displayCurrency)")
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .billioCard()
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
        displayedMonth = Calendar.billio.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }
}
