import SwiftUI
import UniformTypeIdentifiers

struct BillsCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    private let contents: String

    init(bills: [Bill], paymentMethods: [PaymentMethod] = []) {
        let methodsByID = Dictionary(uniqueKeysWithValues: paymentMethods.map { ($0.id, $0.displayName) })
        let header = "Name,Plan,Amount,Currency,Category,Billing Cycle,Next Due Date,Status,Reminder Days,Payment Method,Notes"
        let formatter = ISO8601DateFormatter()
        let rows = bills
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .map { bill in
                [
                    bill.name,
                    bill.subtitle,
                    String(format: "%.2f", bill.amount),
                    bill.currencyCode,
                    bill.category.title,
                    bill.cycle.title,
                    formatter.string(from: bill.nextDueDate),
                    bill.status.title,
                    String(bill.reminderDaysBefore),
                    bill.paymentMethodID.flatMap { methodsByID[$0] } ?? bill.paymentMethodLabel,
                    bill.notes
                ]
                .map(Self.escape)
                .joined(separator: ",")
            }
        contents = ([header] + rows).joined(separator: "\n")
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let contents = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.contents = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(contents.utf8))
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
