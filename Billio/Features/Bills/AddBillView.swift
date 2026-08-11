import SwiftData
import SwiftUI

struct AddBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query private var paymentMethods: [PaymentMethod]
    @Query private var allBills: [Bill]

    @State private var name = ""
    @State private var amount = 0.0
    @State private var currencyCode = "USD"
    @State private var category: BillCategory = .entertainment
    @State private var cycle: BillingCycle = .monthly
    @State private var nextDueDate = Date.billioDate(daysFromToday: 1)
    @State private var notes = ""
    @State private var hasTrial = false
    @State private var trialEndDate = Date.billioDate(daysFromToday: 7)
    @State private var cancellationURL = ""
    @State private var paymentMethodID: UUID?
    @State private var remindMe = true
    @State private var reminderDays = 1
    @State private var hasInitializedCurrency = false
    @State private var initialCurrencyCode = "USD"
    @State private var showingDiscardConfirmation = false
    @FocusState private var focusedField: AddBillField?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: category.symbolName)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(AppTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 20))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Bill details") {
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                    LabeledContent("Amount") {
                        HStack(spacing: 8) {
                            Text(Currency.currency(for: currencyCode).symbol)
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .amount)
                        }
                    }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.supported) { currency in
                            Text("\(currency.code) · \(currency.name)").tag(currency.code)
                        }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(BillCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbolName).tag(category)
                        }
                    }
                    Picker("Billing cycle", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }
                    DatePicker("Next due date", selection: $nextDueDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .notes)
                }

                Section("Plan management") {
                    Toggle("Free trial", isOn: $hasTrial)
                    if hasTrial {
                        DatePicker("Trial ends", selection: $trialEndDate, displayedComponents: .date)
                            .onChange(of: trialEndDate) { _, value in nextDueDate = value }
                    }
                    Picker("Payment method", selection: $paymentMethodID) {
                        Text("None").tag(UUID?.none)
                        ForEach(paymentMethods) { method in
                            Text(method.displayName).tag(Optional(method.id))
                        }
                    }
                    TextField("Cancellation URL (optional)", text: $cancellationURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .cancellationURL)
                    if let suggestion = MerchantCatalog.suggestion(for: name), cancellationURL.isEmpty {
                        Button("Use verified \(suggestion.displayName) cancellation page") {
                            cancellationURL = suggestion.cancellationURL.absoluteString
                            feedbackCenter.selection()
                        }
                    }
                    if !cancellationURL.isEmpty {
                        Label(cancellationValidation.title, systemImage: cancellationValidationSymbol)
                            .font(.caption)
                            .foregroundStyle(cancellationValidationColor)
                    }
                }

                Section {
                    Toggle("Remind me", isOn: $remindMe)
                    if remindMe {
                        Stepper(
                            reminderDays == 1 ? "1 day before" : "\(reminderDays) days before",
                            value: $reminderDays,
                            in: 1...30
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .billioCanvas()
            .navigationTitle("Add Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || amount <= 0
                                || hasInvalidCancellationURL
                        )
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                guard !hasInitializedCurrency else { return }
                currencyCode = exchangeRates.displayCurrency
                initialCurrencyCode = exchangeRates.displayCurrency
                hasInitializedCurrency = true
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Discard this new bill?", isPresented: $showingDiscardConfirmation) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("The information you entered will be lost.")
            }
        }
    }

    private func save() {
        let bill = Bill(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: cycle.title,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            cycle: cycle,
            nextDueDate: nextDueDate,
            notes: notes,
            reminderDaysBefore: remindMe ? reminderDays : 0,
            symbolName: category.symbolName,
            trialEndDate: hasTrial ? trialEndDate : nil,
            cancellationURLString: normalizedURLString,
            cancellationURLVerified: isCancellationURLVerified,
            paymentMethodID: paymentMethodID
        )
        modelContext.insert(bill)
        do {
            try modelContext.save()
            let scheduledBills = Dictionary(
                (allBills + [bill]).map { ($0.id, $0) },
                uniquingKeysWith: { _, newest in newest }
            )
            Task { await notificationManager.reschedule(for: Array(scheduledBills.values)) }
            feedbackCenter.success()
            dismiss()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t save bill")
        }
    }

    private var normalizedURLString: String? {
        let trimmed = cancellationURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    }

    private var cancellationValidation: CancellationURLValidation {
        MerchantCatalog.validate(normalizedURLString, merchantName: name)
    }

    private var hasInvalidCancellationURL: Bool {
        if case .invalid = cancellationValidation { return true }
        return false
    }

    private var isCancellationURLVerified: Bool {
        if case .verified = cancellationValidation { return true }
        return false
    }

    private var cancellationValidationSymbol: String {
        switch cancellationValidation {
        case .verified: "checkmark.shield.fill"
        case .secureUnverified: "exclamationmark.shield.fill"
        case .invalid: "xmark.octagon.fill"
        case .empty: "link"
        }
    }

    private var cancellationValidationColor: Color {
        switch cancellationValidation {
        case .verified: AppTheme.success
        case .secureUnverified: AppTheme.warning
        case .invalid: AppTheme.danger
        case .empty: AppTheme.textSecondary
        }
    }

    private var hasUnsavedChanges: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || amount != 0
            || currencyCode != initialCurrencyCode
            || category != .entertainment
            || cycle != .monthly
            || !nextDueDate.isSameDay(as: .billioDate(daysFromToday: 1))
            || !notes.isEmpty
            || hasTrial
            || !cancellationURL.isEmpty
            || paymentMethodID != nil
            || !remindMe
            || reminderDays != 1
    }

    private func requestDismiss() {
        focusedField = nil
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
}

private enum AddBillField: Hashable {
    case name
    case amount
    case notes
    case cancellationURL
}
