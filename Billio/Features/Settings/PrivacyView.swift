import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                privacySection(
                    "Your data",
                    "Bills, payment confirmations, and payment-method references are stored with SwiftData. When iCloud is available, these records sync through your private CloudKit database."
                )
                privacySection(
                    "Payment information",
                    "Billio does not process payments and never asks for full card numbers, bank credentials, or security codes. Payment methods contain only labels and optional last-four-digit references."
                )
                privacySection(
                    "Exchange rates",
                    "Billio requests current and historical reference rates from Frankfurter. Requests contain currency codes and dates, not your bill names or payment details."
                )
                privacySection(
                    "Notifications",
                    "Bill reminders are scheduled locally on your device. You can disable them at any time in Billio or iOS Settings."
                )
                privacySection(
                    "Export",
                    "CSV exports are created only when you request them and are sent to the location you choose."
                )
                Text("Last updated: August 11, 2026")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(AppTheme.horizontalPadding)
        }
        .billioCanvas()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .billioCard()
    }
}
