import Foundation

struct MerchantCancellationEntry: Identifiable, Equatable {
    let id: String
    let displayName: String
    let keywords: [String]
    let cancellationURL: URL
    let allowedHosts: Set<String>
}

enum CancellationURLValidation: Equatable {
    case empty
    case verified(MerchantCancellationEntry)
    case secureUnverified
    case invalid

    var title: String {
        switch self {
        case .empty: "No cancellation link"
        case .verified: "Verified merchant domain"
        case .secureUnverified: "Secure link · merchant not verified"
        case .invalid: "Invalid or insecure URL"
        }
    }
}

enum MerchantCatalog {
    static let entries: [MerchantCancellationEntry] = [
        entry("netflix", "Netflix", ["netflix"], "https://www.netflix.com/cancelplan", ["netflix.com", "www.netflix.com"]),
        entry("spotify", "Spotify", ["spotify"], "https://www.spotify.com/account/subscription/", ["spotify.com", "www.spotify.com", "accounts.spotify.com"]),
        entry("notion", "Notion", ["notion"], "https://www.notion.so/profile/billing", ["notion.so", "www.notion.so"]),
        entry("adobe", "Adobe", ["adobe", "creative cloud"], "https://account.adobe.com/plans", ["adobe.com", "www.adobe.com", "account.adobe.com"]),
        entry("amazon", "Amazon", ["amazon prime"], "https://www.amazon.com/gp/subs/primeclub/account/homepage.html", ["amazon.com", "www.amazon.com"]),
        entry("youtube", "YouTube", ["youtube", "youtube premium"], "https://www.youtube.com/paid_memberships", ["youtube.com", "www.youtube.com"]),
        entry("disney", "Disney+", ["disney", "disney+"], "https://www.disneyplus.com/account/subscription", ["disneyplus.com", "www.disneyplus.com"])
    ]

    static func suggestion(for merchantName: String) -> MerchantCancellationEntry? {
        let normalized = merchantName.lowercased()
        return entries.first { entry in entry.keywords.contains { normalized.contains($0) } }
    }

    static func validate(_ urlString: String?, merchantName: String) -> CancellationURLValidation {
        guard let urlString, !urlString.isEmpty else { return .empty }
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return .invalid
        }
        if let entry = suggestion(for: merchantName), entry.allowedHosts.contains(host) {
            return .verified(entry)
        }
        return .secureUnverified
    }

    private static func entry(
        _ id: String,
        _ displayName: String,
        _ keywords: [String],
        _ urlString: String,
        _ hosts: Set<String>
    ) -> MerchantCancellationEntry {
        MerchantCancellationEntry(
            id: id,
            displayName: displayName,
            keywords: keywords,
            cancellationURL: URL(string: urlString)!,
            allowedHosts: hosts
        )
    }
}
