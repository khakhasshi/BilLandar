import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(CloudSyncMonitor.self) private var cloudSync
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query private var bills: [Bill]
    @Query private var paymentMethods: [PaymentMethod]
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "12B996"), Color(hex: "008E78")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Billio").font(.headline)
                            Text("Never miss a bill.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Preferences") {
                    Toggle(isOn: notificationBinding) {
                        SettingsLabel(title: "Notifications", symbol: "bell.fill", color: AppTheme.accent)
                    }
                    Picker(selection: displayCurrencyBinding) {
                        ForEach(Currency.supported) { currency in
                            Text("\(currency.code) – \(currency.name)").tag(currency.code)
                        }
                    } label: {
                        SettingsLabel(title: "Currency", symbol: "dollarsign.circle.fill", color: AppTheme.success)
                    }
                    NavigationLink {
                        PaymentMethodsView()
                    } label: {
                        SettingsLabel(title: "Payment methods", symbol: "creditcard.fill", color: Color(hex: "3E8FDE"))
                    }
                }

                Section {
                    LabeledContent("Display currency", value: exchangeRates.displayCurrency)
                    LabeledContent("Status", value: exchangeRates.dataStatusText)
                    if let snapshot = exchangeRates.snapshot {
                        LabeledContent(
                            "Effective date",
                            value: snapshot.effectiveDate.formatted(.dateTime.month(.abbreviated).day().year())
                        )
                        LabeledContent("Source", value: snapshot.source)
                    }
                    Button {
                        Task {
                            await exchangeRates.refresh()
                            exchangeRates.hasUsableRates ? feedbackCenter.success() : feedbackCenter.warning()
                        }
                    } label: {
                        Label(
                            exchangeRates.isLoading ? "Updating…" : "Refresh exchange rates",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(exchangeRates.isLoading)
                } header: {
                    Text("Exchange rates")
                } footer: {
                    Text("Reference rates are used only for statistics. Each bill keeps its original amount and currency.")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: cloudSync.state == .available ? "checkmark.icloud.fill" : "icloud.fill")
                            .foregroundStyle(cloudSync.state == .available ? AppTheme.success : Color(hex: "46A8F0"))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cloudSync.state.title)
                                .font(.subheadline.weight(.semibold))
                            Text(cloudSync.syncDetail)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    Button {
                        Task {
                            await cloudSync.refresh()
                            cloudSync.state == .available ? feedbackCenter.success() : feedbackCenter.warning()
                        }
                    } label: {
                        Label("Check iCloud status", systemImage: "arrow.clockwise")
                    }
                    .disabled(cloudSync.state == .checking)
                    if let lastSuccessfulSyncAt = cloudSync.lastSuccessfulSyncAt {
                        LabeledContent(
                            "Last successful sync",
                            value: lastSuccessfulSyncAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
                        )
                    }
                    if let syncError = cloudSync.lastSyncError {
                        Label(syncError, systemImage: "exclamationmark.icloud.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.danger)
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Bills and payment history use your private CloudKit database. Sync happens automatically when iCloud is available.")
                }

                Section("Data") {
                    Button {
                        isExporting = true
                    } label: {
                        SettingsLabel(title: "Export bills as CSV", symbol: "square.and.arrow.up", color: AppTheme.warning)
                    }
                    .disabled(bills.isEmpty)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text("Privacy")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
            .billioCanvas()
            .billioNavigationTitle("Settings")
            .fileExporter(
                isPresented: $isExporting,
                document: BillsCSVDocument(bills: bills, paymentMethods: paymentMethods),
                contentType: .commaSeparatedText,
                defaultFilename: "Billio-Bills"
            ) { result in
                if case .failure(let error) = result {
                    errorCenter.report(error, title: "Couldn’t export bills")
                } else {
                    feedbackCenter.success()
                }
            }
            .task {
                await exchangeRates.refreshIfNeeded()
                await cloudSync.refresh()
                await notificationManager.refreshStatus()
            }
        }
    }

    private var displayCurrencyBinding: Binding<String> {
        Binding(
            get: { exchangeRates.displayCurrency },
            set: { newValue in
                Task { await exchangeRates.setDisplayCurrency(newValue) }
            }
        )
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: {
                notificationManager.isEnabled
                    && (notificationManager.authorizationState == .authorized
                        || notificationManager.authorizationState == .provisional)
            },
            set: { isEnabled in
                Task {
                    if isEnabled {
                        _ = await notificationManager.enableAndRequestAuthorization(for: bills)
                    } else {
                        await notificationManager.disable()
                    }
                }
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}

private struct SettingsLabel: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            Text(title).foregroundStyle(AppTheme.textPrimary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}
