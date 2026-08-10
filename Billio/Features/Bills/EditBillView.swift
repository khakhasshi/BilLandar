import SwiftData
import SwiftUI

struct EditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query private var paymentMethods: [PaymentMethod]
    @Query private var allBills: [Bill]
    let bill: Bill

    @State private var name: String
    @State private var amount: Double
    @State private var currencyCode: String
    @State private var category: BillCategory
    @State private var cycle: BillingCycle
    @State private var nextDueDate: Date
    @State private var notes: String
    @State private var hasTrial: Bool
    @State private var trialEndDate: Date
    @State private var cancellationURL: String
    @State private var paymentMethodID: UUID?
    @State private var remindMe: Bool
    @State private var reminderDays: Int
    @State private var showingDiscardConfirmation = false
    @FocusState private var focusedField: EditBillField?

    init(bill: Bill) {
        self.bill = bill
        _name = State(initialValue: bill.name)
        _amount = State(initialValue: bill.amount)
        _currencyCode = State(initialValue: bill.currencyCode)
        _category = State(initialValue: bill.category)
        _cycle = State(initialValue: bill.cycle)
        _nextDueDate = State(initialValue: bill.nextDueDate)
        _notes = State(initialValue: bill.notes)
        _hasTrial = State(initialValue: bill.trialEndDate != nil)
        _trialEndDate = State(initialValue: bill.trialEndDate ?? bill.nextDueDate)
        _cancellationURL = State(initialValue: bill.cancellationURLString ?? "")
        _paymentMethodID = State(initialValue: bill.paymentMethodID)
        _remindMe = State(initialValue: bill.reminderDaysBefore > 0)
        _reminderDays = State(initialValue: max(1, bill.reminderDaysBefore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill details") {
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                    TextField("Amount", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.supported) { Text($0.code).tag($0.code) }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(BillCategory.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Billing cycle", selection: $cycle) {
                        ForEach(BillingCycle.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Next due date", selection: $nextDueDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical)
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
                    TextField("Cancellation URL", text: $cancellationURL)
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
                        Label(validation.title, systemImage: validationSymbol)
                            .font(.caption)
                            .foregroundStyle(validationColor)
                    }
                }

                Section("Reminder") {
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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: requestDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
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
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog("Discard your changes?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("This bill will remain unchanged.")
            }
        }
    }

    private func save() {
        bill.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bill.amount = amount
        bill.currencyCode = currencyCode
        bill.category = category
        bill.cycle = cycle
        bill.nextDueDate = hasTrial ? trialEndDate : nextDueDate
        bill.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        bill.trialEndDate = hasTrial ? trialEndDate : nil
        bill.cancellationURLString = normalizedURLString
        if case .verified = validation { bill.cancellationURLVerified = true } else { bill.cancellationURLVerified = false }
        bill.paymentMethodID = paymentMethodID
        bill.paymentMethodLabel = ""
        bill.reminderDaysBefore = remindMe ? reminderDays : 0
        bill.symbolName = category.symbolName
        bill.merchantIdentifier = Bill.normalizedMerchantIdentifier(from: bill.name)
        bill.updatedAt = .now

        do {
            try modelContext.save()
            Task { await notificationManager.reschedule(for: allBills) }
            feedbackCenter.success()
            dismiss()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t update bill")
        }
    }

    private var normalizedURLString: String? {
        let trimmed = cancellationURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    }

    private var validation: CancellationURLValidation {
        MerchantCatalog.validate(normalizedURLString, merchantName: name)
    }

    private var hasInvalidCancellationURL: Bool {
        if case .invalid = validation { return true }
        return false
    }

    private var validationSymbol: String {
        switch validation {
        case .verified: "checkmark.shield.fill"
        case .secureUnverified: "exclamationmark.shield.fill"
        case .invalid: "xmark.octagon.fill"
        case .empty: "link"
        }
    }

    private var validationColor: Color {
        switch validation {
        case .verified: AppTheme.success
        case .secureUnverified: AppTheme.warning
        case .invalid: AppTheme.danger
        case .empty: AppTheme.textSecondary
        }
    }

    private var hasUnsavedChanges: Bool {
        name != bill.name
            || amount != bill.amount
            || currencyCode != bill.currencyCode
            || category != bill.category
            || cycle != bill.cycle
            || nextDueDate != bill.nextDueDate
            || notes != bill.notes
            || hasTrial != (bill.trialEndDate != nil)
            || trialEndDate != (bill.trialEndDate ?? bill.nextDueDate)
            || cancellationURL != (bill.cancellationURLString ?? "")
            || paymentMethodID != bill.paymentMethodID
            || remindMe != (bill.reminderDaysBefore > 0)
            || reminderDays != max(1, bill.reminderDaysBefore)
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

private enum EditBillField: Hashable {
    case name
    case amount
    case notes
    case cancellationURL
}
