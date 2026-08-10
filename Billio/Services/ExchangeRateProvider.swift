import Foundation

struct ExchangeRateSnapshot: Codable, Equatable {
    let baseCurrency: String
    let rates: [String: Double]
    let effectiveDate: Date
    let fetchedAt: Date
    let source: String

    func convert(_ amount: Double, from sourceCurrency: String) -> Double? {
        if sourceCurrency == baseCurrency { return amount }
        guard let sourceUnitsPerBaseUnit = rates[sourceCurrency], sourceUnitsPerBaseUnit > 0 else {
            return nil
        }
        return amount / sourceUnitsPerBaseUnit
    }
}

protocol ExchangeRateProviding {
    func latestRates(baseCurrency: String, quoteCurrencies: Set<String>) async throws -> ExchangeRateSnapshot
    func historicalRates(
        baseCurrency: String,
        quoteCurrencies: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [ExchangeRateSnapshot]
}

extension ExchangeRateProviding {
    func historicalRates(
        baseCurrency: String,
        quoteCurrencies: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [ExchangeRateSnapshot] {
        []
    }
}

enum ExchangeRateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyRates

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The exchange-rate request could not be created."
        case .invalidResponse: "The exchange-rate service returned an invalid response."
        case .emptyRates: "No exchange rates were available for these currencies."
        }
    }
}

struct FrankfurterExchangeRateProvider: ExchangeRateProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRates(baseCurrency: String, quoteCurrencies: Set<String>) async throws -> ExchangeRateSnapshot {
        let normalizedBase = baseCurrency.uppercased()
        let quotes = quoteCurrencies
            .map { $0.uppercased() }
            .filter { $0 != normalizedBase }
            .sorted()

        guard !quotes.isEmpty else {
            return ExchangeRateSnapshot(
                baseCurrency: normalizedBase,
                rates: [normalizedBase: 1],
                effectiveDate: .now,
                fetchedAt: .now,
                source: "Identity rate"
            )
        }

        var components = URLComponents(string: "https://api.frankfurter.dev/v2/rates")
        components?.queryItems = [
            URLQueryItem(name: "base", value: normalizedBase),
            URLQueryItem(name: "quotes", value: quotes.joined(separator: ","))
        ]
        guard let url = components?.url else { throw ExchangeRateError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ExchangeRateError.invalidResponse
        }

        let records = try JSONDecoder().decode([FrankfurterRateRecord].self, from: data)
        guard !records.isEmpty else { throw ExchangeRateError.emptyRates }

        var rates = Dictionary(uniqueKeysWithValues: records.map { ($0.quote, $0.rate) })
        guard Set(quotes).isSubset(of: Set(rates.keys)) else { throw ExchangeRateError.emptyRates }
        rates[normalizedBase] = 1

        let dateText = records.map(\.date).max() ?? ""
        let effectiveDate = ISO8601DateFormatter().date(from: "\(dateText)T00:00:00Z") ?? .now

        return ExchangeRateSnapshot(
            baseCurrency: normalizedBase,
            rates: rates,
            effectiveDate: effectiveDate,
            fetchedAt: .now,
            source: "Frankfurter reference rates"
        )
    }

    func historicalRates(
        baseCurrency: String,
        quoteCurrencies: Set<String>,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [ExchangeRateSnapshot] {
        let normalizedBase = baseCurrency.uppercased()
        let quotes = quoteCurrencies
            .map { $0.uppercased() }
            .filter { $0 != normalizedBase }
            .sorted()
        guard !quotes.isEmpty else { return [] }

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = .billio
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: "https://api.frankfurter.dev/v2/rates")
        components?.queryItems = [
            URLQueryItem(name: "base", value: normalizedBase),
            URLQueryItem(name: "quotes", value: quotes.joined(separator: ",")),
            URLQueryItem(name: "from", value: dayFormatter.string(from: startDate)),
            URLQueryItem(name: "to", value: dayFormatter.string(from: endDate))
        ]
        guard let url = components?.url else { throw ExchangeRateError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ExchangeRateError.invalidResponse
        }

        let records = try JSONDecoder().decode([FrankfurterRateRecord].self, from: data)
        guard !records.isEmpty else { throw ExchangeRateError.emptyRates }

        return Dictionary(grouping: records, by: \.date)
            .compactMap { dateText, dateRecords in
                guard let date = dayFormatter.date(from: dateText) else { return nil }
                var rates = Dictionary(uniqueKeysWithValues: dateRecords.map { ($0.quote, $0.rate) })
                rates[normalizedBase] = 1
                return ExchangeRateSnapshot(
                    baseCurrency: normalizedBase,
                    rates: rates,
                    effectiveDate: date,
                    fetchedAt: .now,
                    source: "Frankfurter historical reference rates"
                )
            }
            .sorted { $0.effectiveDate < $1.effectiveDate }
    }
}

private struct FrankfurterRateRecord: Decodable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
