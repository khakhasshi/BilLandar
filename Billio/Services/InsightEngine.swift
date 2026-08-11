import Foundation

struct BillInsight: Identifiable, Equatable {
    enum Kind: String {
        case duplicate
        case priceIncrease
        case trialEnding
        case paymentIssue
        case renewalCluster
    }

    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case critical = 2

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let id: String
    let kind: Kind
    let severity: Severity
    let title: String
    let message: String
    let billIDs: [UUID]

    var symbolName: String {
        switch kind {
        case .duplicate: "square.on.square"
        case .priceIncrease: "chart.line.uptrend.xyaxis"
        case .trialEnding: "hourglass.bottomhalf.filled"
        case .paymentIssue: "exclamationmark.circle.fill"
        case .renewalCluster: "calendar.badge.exclamationmark"
        }
    }
}

enum InsightEngine {
    static func generate(
        bills: [Bill],
        payments: [PaymentRecord],
        now: Date = .now,
        calendar: Calendar = .billio
    ) -> [BillInsight] {
        var insights: [BillInsight] = []
        let activeBills = bills.filter { $0.status == .active }

        insights.append(contentsOf: duplicateInsights(from: activeBills))
        insights.append(contentsOf: priceInsights(bills: activeBills, payments: payments))
        insights.append(contentsOf: trialInsights(from: activeBills, now: now, calendar: calendar))
        insights.append(contentsOf: paymentIssueInsights(bills: activeBills, payments: payments))

        if let cluster = renewalClusterInsight(from: activeBills, now: now, calendar: calendar) {
            insights.append(cluster)
        }

        return insights.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return $0.title < $1.title
        }
    }

    private static func duplicateInsights(from bills: [Bill]) -> [BillInsight] {
        Dictionary(grouping: bills) { bill in
            bill.merchantIdentifier.isEmpty
                ? Bill.normalizedMerchantIdentifier(from: bill.name)
                : bill.merchantIdentifier
        }
        .filter { !$0.key.isEmpty && $0.value.count > 1 }
        .map { merchant, duplicates in
            BillInsight(
                id: "duplicate-\(merchant)",
                kind: .duplicate,
                severity: .critical,
                title: String(localized: "Possible duplicate subscription", locale: BillioSharedStore.appLocale),
                message: String(
                    format: String(localized: "%@ appear to bill the same service.", locale: BillioSharedStore.appLocale),
                    duplicates.map(\.name).joined(separator: String(localized: " and ", locale: BillioSharedStore.appLocale))
                ),
                billIDs: duplicates.map(\.id)
            )
        }
    }

    private static func priceInsights(bills: [Bill], payments: [PaymentRecord]) -> [BillInsight] {
        bills.compactMap { bill in
            let history = payments
                .filter { $0.billID == bill.id && $0.status == .paid && $0.currencyCode == bill.currencyCode }
                .sorted { $0.paidAt > $1.paidAt }
            guard let recent = history.first else { return nil }

            let olderAmounts = history.dropFirst().map(\.amount)
            guard let previous = olderAmounts.first(where: { $0 < recent.amount * 0.995 }), previous > 0 else {
                return nil
            }

            let change = (recent.amount - previous) / previous
            return BillInsight(
                id: "price-\(bill.id.uuidString)",
                kind: .priceIncrease,
                severity: change >= 0.1 ? .critical : .warning,
                title: String(
                    format: String(localized: "%@ price increased", locale: BillioSharedStore.appLocale),
                    bill.name
                ),
                message: String(
                    format: String(localized: "Up %@ from %@ to %@.", locale: BillioSharedStore.appLocale),
                    change.formatted(.percent.precision(.fractionLength(0)).locale(BillioSharedStore.appLocale)),
                    previous.formatted(.currency(code: bill.currencyCode).locale(BillioSharedStore.appLocale)),
                    recent.amount.formatted(.currency(code: bill.currencyCode).locale(BillioSharedStore.appLocale))
                ),
                billIDs: [bill.id]
            )
        }
    }

    private static func trialInsights(from bills: [Bill], now: Date, calendar: Calendar) -> [BillInsight] {
        bills.compactMap { bill in
            guard let trialEndDate = bill.trialEndDate else { return nil }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: trialEndDate)
            ).day ?? 0
            guard (0...7).contains(days) else { return nil }

            return BillInsight(
                id: "trial-\(bill.id.uuidString)",
                kind: .trialEnding,
                severity: days <= 2 ? .critical : .warning,
                title: String(
                    format: String(localized: "%@ trial ends soon", locale: BillioSharedStore.appLocale),
                    bill.name
                ),
                message: days == 0
                    ? String(localized: "The trial converts to a paid plan today.", locale: BillioSharedStore.appLocale)
                    : String(
                        format: String(localized: "The trial converts to %@ in %lld days.", locale: BillioSharedStore.appLocale),
                        bill.amount.formatted(.currency(code: bill.currencyCode).locale(BillioSharedStore.appLocale)),
                        days
                    ),
                billIDs: [bill.id]
            )
        }
    }

    private static func paymentIssueInsights(bills: [Bill], payments: [PaymentRecord]) -> [BillInsight] {
        bills.compactMap { bill in
            guard let latest = payments
                .filter({ $0.billID == bill.id })
                .max(by: { $0.paidAt < $1.paidAt }),
                  latest.status == .failed else { return nil }

            return BillInsight(
                id: "payment-\(bill.id.uuidString)",
                kind: .paymentIssue,
                severity: .critical,
                title: String(localized: "Payment needs attention", locale: BillioSharedStore.appLocale),
                message: String(
                    format: String(localized: "The latest %@ payment failed.", locale: BillioSharedStore.appLocale),
                    bill.name
                ),
                billIDs: [bill.id]
            )
        }
    }

    private static func renewalClusterInsight(
        from bills: [Bill],
        now: Date,
        calendar: Calendar
    ) -> BillInsight? {
        let endDate = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let upcoming = bills.filter { $0.nextDueDate >= now.startOfDay && $0.nextDueDate <= endDate }
        guard upcoming.count >= 4 else { return nil }

        return BillInsight(
            id: "renewal-cluster",
            kind: .renewalCluster,
            severity: .info,
            title: String(localized: "Busy renewal week", locale: BillioSharedStore.appLocale),
            message: String(
                format: String(localized: "%lld bills renew in the next 7 days.", locale: BillioSharedStore.appLocale),
                upcoming.count
            ),
            billIDs: upcoming.map(\.id)
        )
    }
}
