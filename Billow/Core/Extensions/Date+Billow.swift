import Foundation

extension Calendar {
    nonisolated static let billow = Calendar(identifier: .gregorian)
}

extension Date {
    static func billowDate(daysFromToday days: Int) -> Date {
        Calendar.billow.date(byAdding: .day, value: days, to: .now) ?? .now
    }

    var startOfDay: Date { Calendar.billow.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.billow.isDate(self, inSameDayAs: other)
    }
}
