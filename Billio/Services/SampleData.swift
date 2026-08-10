import Foundation
import SwiftData

@MainActor
enum SampleData {
    static func seedIfNeeded(in context: ModelContext) throws {
        let billDescriptor = FetchDescriptor<Bill>(sortBy: [SortDescriptor(\Bill.nextDueDate)])
        var bills = try context.fetch(billDescriptor)

        if bills.isEmpty {
            bills = sampleBills
            bills.forEach(context.insert)
        } else {
            for bill in bills where bill.merchantIdentifier.isEmpty {
                bill.merchantIdentifier = Bill.normalizedMerchantIdentifier(from: bill.name)
            }
        }

        let paymentDescriptor = FetchDescriptor<PaymentRecord>()
        if try context.fetchCount(paymentDescriptor) == 0 {
            paymentHistory(for: bills).forEach(context.insert)
        }

        let methodDescriptor = FetchDescriptor<PaymentMethod>()
        var methods = try context.fetch(methodDescriptor)
        if methods.isEmpty {
            methods = [
                PaymentMethod(name: "Personal Visa", type: .card, issuer: "Visa", lastFour: "4242", isDefault: true),
                PaymentMethod(name: "Travel Mastercard", type: .card, issuer: "Mastercard", lastFour: "8088"),
                PaymentMethod(name: "Apple Pay", type: .applePay)
            ]
            methods.forEach(context.insert)
        }

        for bill in bills where bill.paymentMethodID == nil {
            if bill.paymentMethodLabel.contains("4242") {
                bill.paymentMethodID = methods.first { $0.lastFour == "4242" }?.id
            } else if bill.paymentMethodLabel.contains("8088") {
                bill.paymentMethodID = methods.first { $0.lastFour == "8088" }?.id
            } else if bill.paymentMethodLabel.localizedCaseInsensitiveContains("Apple Pay") {
                bill.paymentMethodID = methods.first { $0.type == .applePay }?.id
            }
        }

        for bill in bills {
            let validation = MerchantCatalog.validate(bill.cancellationURLString, merchantName: bill.name)
            if case .verified = validation { bill.cancellationURLVerified = true }
        }

        try context.save()
    }

    static var sampleBills: [Bill] {
        [
            Bill(
                name: "Netflix",
                subtitle: "Standard Plan",
                amount: 15.49,
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 1),
                notes: "Primary household plan",
                symbolName: "play.fill",
                brandColorHex: "141414",
                merchantIdentifier: "netflix",
                cancellationURLString: "https://www.netflix.com/cancelplan",
                paymentMethodLabel: "Visa •••• 4242"
            ),
            Bill(
                name: "Netflix Family",
                subtitle: "Family Plan",
                amount: 22.99,
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 4),
                notes: "Possible duplicate subscription",
                symbolName: "person.2.fill",
                brandColorHex: "B20710",
                merchantIdentifier: "netflix",
                cancellationURLString: "https://www.netflix.com/cancelplan"
            ),
            Bill(
                name: "Spotify",
                subtitle: "Premium Individual",
                amount: 11.99,
                currencyCode: "EUR",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 1),
                symbolName: "waveform",
                brandColorHex: "1DB954",
                merchantIdentifier: "spotify",
                cancellationURLString: "https://www.spotify.com/account/subscription/",
                paymentMethodLabel: "Mastercard •••• 8088"
            ),
            Bill(
                name: "iCloud+",
                subtitle: "200 GB Storage",
                amount: 2.99,
                category: .storage,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 1),
                symbolName: "cloud.fill",
                brandColorHex: "46A8F0",
                merchantIdentifier: "icloud"
            ),
            Bill(
                name: "ChatGPT Plus",
                subtitle: "Plus Subscription",
                amount: 20,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 3),
                symbolName: "sparkles",
                brandColorHex: "10A37F",
                merchantIdentifier: "chatgpt",
                paymentMethodLabel: "Apple Pay"
            ),
            Bill(
                name: "Notion AI",
                subtitle: "Free Trial",
                amount: 10,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 5),
                notes: "Trial converts to a paid plan",
                symbolName: "doc.text.fill",
                brandColorHex: "2F3437",
                merchantIdentifier: "notion-ai",
                trialEndDate: .billioDate(daysFromToday: 5),
                cancellationURLString: "https://www.notion.so/profile/billing"
            ),
            Bill(
                name: "YouTube Premium",
                subtitle: "Family Plan",
                amount: 128,
                currencyCode: "HKD",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 6),
                symbolName: "play.rectangle.fill",
                brandColorHex: "FF0033",
                merchantIdentifier: "youtube-premium"
            ),
            Bill(
                name: "Disney+",
                subtitle: "Monthly Plan",
                amount: 55,
                currencyCode: "CNY",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 8),
                status: .paused,
                symbolName: "sparkle",
                brandColorHex: "163A70",
                merchantIdentifier: "disney-plus"
            ),
            Bill(
                name: "Amazon Prime",
                subtitle: "Annual Plan",
                amount: 139,
                category: .other,
                cycle: .yearly,
                nextDueDate: .billioDate(daysFromToday: 20),
                symbolName: "shippingbox.fill",
                brandColorHex: "168A93",
                merchantIdentifier: "amazon-prime"
            ),
            Bill(
                name: "Adobe Creative Cloud",
                subtitle: "Photography Plan",
                amount: 19.99,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billioDate(daysFromToday: 12),
                symbolName: "camera.aperture",
                brandColorHex: "E83B3B",
                merchantIdentifier: "adobe-creative-cloud"
            )
        ]
    }

    static func paymentHistory(for bills: [Bill]) -> [PaymentRecord] {
        var records = bills.flatMap { bill in
            let recordCount: Int
            switch bill.cycle {
            case .weekly: recordCount = 10
            case .monthly: recordCount = 6
            case .quarterly: recordCount = 3
            case .yearly: recordCount = 1
            }

            return (1...recordCount).map { offset in
                let paidAt: Date
                switch bill.cycle {
                case .weekly:
                    paidAt = Calendar.billio.date(byAdding: .weekOfYear, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                case .monthly:
                    paidAt = Calendar.billio.date(byAdding: .month, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                case .quarterly:
                    paidAt = Calendar.billio.date(byAdding: .month, value: -(offset * 3), to: bill.nextDueDate) ?? bill.nextDueDate
                case .yearly:
                    paidAt = Calendar.billio.date(byAdding: .year, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                }

                let historicalAmount: Double
                if bill.merchantIdentifier == "spotify", offset >= 2 {
                    historicalAmount = 10.99
                } else if bill.merchantIdentifier == "netflix", offset >= 4 {
                    historicalAmount = bill.name == "Netflix" ? 13.99 : bill.amount
                } else {
                    historicalAmount = bill.amount
                }

                return PaymentRecord(
                    billID: bill.id,
                    billName: bill.name,
                    amount: historicalAmount,
                    currencyCode: bill.currencyCode,
                    paidAt: paidAt,
                    status: .paid
                )
            }
        }

        if let adobe = bills.first(where: { $0.merchantIdentifier == "adobe-creative-cloud" }) {
            records.append(
                PaymentRecord(
                    billID: adobe.id,
                    billName: adobe.name,
                    amount: adobe.amount,
                    currencyCode: adobe.currencyCode,
                    paidAt: .billioDate(daysFromToday: -2),
                    status: .failed,
                    note: "Payment method declined"
                )
            )
        }

        return records
    }
}
