import Foundation

extension Calendar {
    nonisolated static let billio = Calendar(identifier: .gregorian)
}

extension Date {
    static func billioDate(daysFromToday days: Int) -> Date {
        Calendar.billio.date(byAdding: .day, value: days, to: .now) ?? .now
    }

    var startOfDay: Date { Calendar.billio.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.billio.isDate(self, inSameDayAs: other)
    }
}
