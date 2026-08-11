import SwiftData
import SwiftUI

struct PaymentRecordEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    let payment: PaymentRecord

    @State private var amount: Double
    @State private var currencyCode: String
    @State private var paidAt: Date
    @State private var dueDate: Date
    @State private var status: PaymentStatus
    @State private var note: String
    @State private var showingDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    init(payment: PaymentRecord) {
        self.payment = payment
        _amount = State(initialValue: payment.amount)
        _currencyCode = State(initialValue: payment.currencyCode)
        _paidAt = State(initialValue: payment.paidAt)
        _dueDate = State(initialValue: payment.dueDate)
        _status = State(initialValue: payment.status)
        _note = State(initialValue: payment.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    Picker("Status", selection: $status) {
                        ForEach(PaymentStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    LabeledContent("Amount") {
                        TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .amount)
                    }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Currency.supported) { currency in
                            Text("\(currency.code) · \(currency.name)").tag(currency.code)
                        }
                    }
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    if status != .pending {
                        DatePicker("Recorded date", selection: $paidAt, displayedComponents: [.date, .hourAndMinute])
                    }
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .note)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(amount <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Discard payment changes?", isPresented: $showingDiscardConfirmation) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("The information you entered will be lost.")
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        amount != payment.amount
            || currencyCode != payment.currencyCode
            || paidAt != payment.paidAt
            || dueDate != payment.dueDate
            || status != payment.status
            || note != payment.note
    }

    private func save() {
        payment.amount = amount
        payment.currencyCode = currencyCode
        payment.paidAt = paidAt
        payment.dueDate = dueDate
        payment.status = status
        payment.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try modelContext.save()
            feedbackCenter.success()
            dismiss()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t update payment")
        }
    }

    private func requestDismiss() {
        focusedField = nil
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private enum Field: Hashable {
        case amount
        case note
    }
}
