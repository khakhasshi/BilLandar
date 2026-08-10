import Foundation

struct Currency: Identifiable, Hashable {
    let code: String
    let name: String
    let symbol: String

    var id: String { code }

    static let supported: [Currency] = [
        Currency(code: "USD", name: "US Dollar", symbol: "$"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        Currency(code: "EUR", name: "Euro", symbol: "€"),
        Currency(code: "GBP", name: "British Pound", symbol: "£"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        Currency(code: "CHF", name: "Swiss Franc", symbol: "CHF")
    ]

    static func currency(for code: String) -> Currency {
        supported.first { $0.code == code } ?? Currency(code: code, name: code, symbol: code)
    }
}

extension Bill {
    var monthlyEquivalentAmount: Double {
        switch cycle {
        case .weekly: amount * 52 / 12
        case .monthly: amount
        case .quarterly: amount / 3
        case .yearly: amount / 12
        }
    }
}
