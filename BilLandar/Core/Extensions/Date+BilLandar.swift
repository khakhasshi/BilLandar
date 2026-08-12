import Foundation

extension Calendar {
    nonisolated static let billandar = Calendar(identifier: .gregorian)
}

extension Date {
    static func billandarDate(daysFromToday days: Int) -> Date {
        Calendar.billandar.date(byAdding: .day, value: days, to: .now) ?? .now
    }

    var startOfDay: Date { Calendar.billandar.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.billandar.isDate(self, inSameDayAs: other)
    }
}
