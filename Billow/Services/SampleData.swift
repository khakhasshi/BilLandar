import Foundation
import SwiftData

@MainActor
enum SampleData {
    private static let legacySimulatorNameMap: [String: String] = [
        "Netflix": "Streamly",
        "Netflix Family": "Streamly Family",
        "Spotify": "EchoBeat",
        "iCloud+": "CloudNest+",
        "ChatGPT Plus": "Nova AI",
        "Notion AI": "NoteForge AI",
        "YouTube Premium": "CinemaFlow Premium",
        "Disney+": "Starry+",
        "Amazon Prime": "ParcelPass",
        "Adobe Creative Cloud": "PixelForge Suite"
    ]

    /// Replaces only the complete legacy seed set in an existing simulator store.
    /// User-created records are left untouched when the store contains anything
    /// outside that exact set.
    static func migrateLegacySimulatorDataIfNeeded(in context: ModelContext) throws {
        let bills = try context.fetch(FetchDescriptor<Bill>())
        guard bills.count == legacySimulatorNameMap.count,
              Set(bills.map(\.name)) == Set(legacySimulatorNameMap.keys) else { return }

        let replacements = Dictionary(uniqueKeysWithValues: sampleBills.map { ($0.name, $0) })
        var replacementNamesByID: [UUID: String] = [:]

        for bill in bills {
            guard let replacementName = legacySimulatorNameMap[bill.name],
                  let replacement = replacements[replacementName] else { continue }
            replacementNamesByID[bill.id] = replacement.name
            bill.name = replacement.name
            bill.subtitle = replacement.subtitle
            bill.amount = replacement.amount
            bill.currencyCode = replacement.currencyCode
            bill.categoryRawValue = replacement.categoryRawValue
            bill.cycleRawValue = replacement.cycleRawValue
            bill.notes = replacement.notes
            bill.symbolName = replacement.symbolName
            bill.brandColorHex = replacement.brandColorHex
            bill.merchantIdentifier = replacement.merchantIdentifier
            bill.trialEndDate = replacement.trialEndDate
            bill.paymentMethodLabel = replacement.paymentMethodLabel
            bill.cancellationURLString = nil
            bill.cancellationURLVerified = false
            bill.updatedAt = .now
        }

        for payment in try context.fetch(FetchDescriptor<PaymentRecord>()) {
            if let replacementName = replacementNamesByID[payment.billID] {
                payment.billName = replacementName
            }
        }

        let legacyPaymentMethods = try context.fetch(FetchDescriptor<PaymentMethod>())
        if legacyPaymentMethods.count == 3,
           Set(legacyPaymentMethods.map(\.name)) == ["Personal Visa", "Travel Mastercard", "Apple Pay"] {
            for method in legacyPaymentMethods {
                switch method.name {
                case "Personal Visa":
                    method.name = "Personal Card"
                    method.issuer = "Card Network"
                case "Travel Mastercard":
                    method.name = "Travel Card"
                    method.issuer = "Card Network"
                case "Apple Pay":
                    method.name = "Digital Wallet"
                    method.type = .wallet
                    method.issuer = ""
                default:
                    break
                }
                method.updatedAt = .now
            }
        }

        try context.save()
    }

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
                PaymentMethod(name: "Personal Card", type: .card, issuer: "Card Network", lastFour: "4242", isDefault: true),
                PaymentMethod(name: "Travel Card", type: .card, issuer: "Card Network", lastFour: "8088"),
                PaymentMethod(name: "Digital Wallet", type: .wallet)
            ]
            methods.forEach(context.insert)
        }

        for bill in bills where bill.paymentMethodID == nil {
            if bill.paymentMethodLabel.contains("4242") {
                bill.paymentMethodID = methods.first { $0.lastFour == "4242" }?.id
            } else if bill.paymentMethodLabel.contains("8088") {
                bill.paymentMethodID = methods.first { $0.lastFour == "8088" }?.id
            } else if bill.paymentMethodLabel.localizedCaseInsensitiveContains("Digital Wallet") {
                bill.paymentMethodID = methods.first { $0.type == .wallet }?.id
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
                name: "Streamly",
                subtitle: "Standard Plan",
                amount: 15.49,
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 1),
                notes: "Primary household plan",
                symbolName: "play.fill",
                brandColorHex: "141414",
                merchantIdentifier: "streamly",
                paymentMethodLabel: "Personal Card •••• 4242"
            ),
            Bill(
                name: "Streamly Family",
                subtitle: "Family Plan",
                amount: 22.99,
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 4),
                notes: "Possible duplicate subscription",
                symbolName: "person.2.fill",
                brandColorHex: "B20710",
                merchantIdentifier: "streamly"
            ),
            Bill(
                name: "EchoBeat",
                subtitle: "Premium Individual",
                amount: 11.99,
                currencyCode: "EUR",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 1),
                symbolName: "waveform",
                brandColorHex: "1DB954",
                merchantIdentifier: "echobeat",
                paymentMethodLabel: "Travel Card •••• 8088"
            ),
            Bill(
                name: "CloudNest+",
                subtitle: "200 GB Storage",
                amount: 2.99,
                category: .storage,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 1),
                symbolName: "cloud.fill",
                brandColorHex: "46A8F0",
                merchantIdentifier: "cloudnest"
            ),
            Bill(
                name: "Nova AI",
                subtitle: "Plus Subscription",
                amount: 20,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 3),
                symbolName: "sparkles",
                brandColorHex: "10A37F",
                merchantIdentifier: "nova-ai",
                paymentMethodLabel: "Digital Wallet"
            ),
            Bill(
                name: "NoteForge AI",
                subtitle: "Free Trial",
                amount: 10,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 5),
                notes: "Trial converts to a paid plan",
                symbolName: "doc.text.fill",
                brandColorHex: "2F3437",
                merchantIdentifier: "noteforge-ai",
                trialEndDate: .billowDate(daysFromToday: 5),
            ),
            Bill(
                name: "CinemaFlow Premium",
                subtitle: "Family Plan",
                amount: 128,
                currencyCode: "HKD",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 6),
                symbolName: "play.rectangle.fill",
                brandColorHex: "FF0033",
                merchantIdentifier: "cinemaflow-premium"
            ),
            Bill(
                name: "Starry+",
                subtitle: "Monthly Plan",
                amount: 55,
                currencyCode: "CNY",
                category: .entertainment,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 8),
                status: .paused,
                symbolName: "sparkle",
                brandColorHex: "163A70",
                merchantIdentifier: "starry-plus"
            ),
            Bill(
                name: "ParcelPass",
                subtitle: "Annual Plan",
                amount: 139,
                category: .other,
                cycle: .yearly,
                nextDueDate: .billowDate(daysFromToday: 20),
                symbolName: "shippingbox.fill",
                brandColorHex: "168A93",
                merchantIdentifier: "parcelpass"
            ),
            Bill(
                name: "PixelForge Suite",
                subtitle: "Photography Plan",
                amount: 19.99,
                category: .productivity,
                cycle: .monthly,
                nextDueDate: .billowDate(daysFromToday: 12),
                symbolName: "camera.aperture",
                brandColorHex: "E83B3B",
                merchantIdentifier: "pixelforge-suite"
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
                    paidAt = Calendar.billow.date(byAdding: .weekOfYear, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                case .monthly:
                    paidAt = Calendar.billow.date(byAdding: .month, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                case .quarterly:
                    paidAt = Calendar.billow.date(byAdding: .month, value: -(offset * 3), to: bill.nextDueDate) ?? bill.nextDueDate
                case .yearly:
                    paidAt = Calendar.billow.date(byAdding: .year, value: -offset, to: bill.nextDueDate) ?? bill.nextDueDate
                }

                let historicalAmount: Double
                if bill.merchantIdentifier == "echobeat", offset >= 2 {
                    historicalAmount = 10.99
                } else if bill.merchantIdentifier == "streamly", offset >= 4 {
                    historicalAmount = bill.name == "Streamly" ? 13.99 : bill.amount
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

        if let pixelForge = bills.first(where: { $0.merchantIdentifier == "pixelforge-suite" }) {
            records.append(
                PaymentRecord(
                    billID: pixelForge.id,
                    billName: pixelForge.name,
                    amount: pixelForge.amount,
                    currencyCode: pixelForge.currencyCode,
                    paidAt: .billowDate(daysFromToday: -2),
                    status: .failed,
                    note: "Payment method declined"
                )
            )
        }

        return records
    }
}
