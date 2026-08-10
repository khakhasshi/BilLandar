import SwiftData
import SwiftUI

struct PaymentMethodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query(sort: \PaymentMethod.createdAt) private var methods: [PaymentMethod]
    @Query private var bills: [Bill]
    @State private var showingAddMethod = false
    @State private var methodToDelete: PaymentMethod?

    var body: some View {
        List {
            if methods.isEmpty {
                ContentUnavailableView(
                    "No payment methods",
                    systemImage: "creditcard",
                    description: Text("Store a safe reference such as card issuer and last four digits. Billio never stores full card numbers or credentials.")
                )
            } else {
                ForEach(methods) { method in
                    HStack(spacing: 12) {
                        Image(systemName: method.type.symbolName)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(method.displayName).font(.subheadline.weight(.semibold))
                            Text(method.type.title)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if method.isDefault {
                            Text("Default")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { methodToDelete = method }
                        if !method.isDefault {
                            Button("Default") { makeDefault(method) }
                                .tint(AppTheme.accent)
                        }
                    }
                    .contextMenu {
                        if !method.isDefault {
                            Button("Make Default") { makeDefault(method) }
                        }
                        Button("Delete", role: .destructive) { methodToDelete = method }
                    }
                }
            }
        }
        .navigationTitle("Payment Methods")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddMethod = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddMethod) {
            AddPaymentMethodView(hasExistingDefault: methods.contains(where: \.isDefault))
        }
        .confirmationDialog(
            "Delete \(methodToDelete?.displayName ?? "payment method")?",
            isPresented: Binding(
                get: { methodToDelete != nil },
                set: { if !$0 { methodToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Payment Method", role: .destructive) {
                if let methodToDelete { delete(methodToDelete) }
                methodToDelete = nil
            }
            Button("Cancel", role: .cancel) { methodToDelete = nil }
        } message: {
            Text("Bills using this reference will be changed to no payment method.")
        }
    }

    private func makeDefault(_ selected: PaymentMethod) {
        methods.forEach { $0.isDefault = $0.id == selected.id }
        save(title: "Couldn’t update payment method")
    }

    private func delete(_ method: PaymentMethod) {
        bills.filter { $0.paymentMethodID == method.id }.forEach { $0.paymentMethodID = nil }
        if method.isDefault {
            methods.first { $0.id != method.id }?.isDefault = true
        }
        modelContext.delete(method)
        save(title: "Couldn’t delete payment method")
    }

    private func save(title: String) {
        do {
            try modelContext.save()
            feedbackCenter.success()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: title)
        }
    }
}

private struct AddPaymentMethodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    let hasExistingDefault: Bool

    @State private var name = ""
    @State private var issuer = ""
    @State private var lastFour = ""
    @State private var type: PaymentMethodType = .card
    @State private var isDefault = false
    @State private var initialDefault = false
    @State private var showingDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Personal Visa", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .issuer }
                    Picker("Type", selection: $type) {
                        ForEach(PaymentMethodType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Issuer (optional)", text: $issuer)
                        .focused($focusedField, equals: .issuer)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastFour }
                    TextField("Last four digits (optional)", text: $lastFour)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .lastFour)
                        .onChange(of: lastFour) { _, value in
                            lastFour = String(value.filter(\.isNumber).prefix(4))
                        }
                    Toggle("Default method", isOn: $isDefault)
                } header: {
                    Text("Reference")
                } footer: {
                    Text("Only a display name, issuer, and up to four digits are saved. Never enter a full card or bank account number.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                isDefault = !hasExistingDefault
                initialDefault = isDefault
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog("Discard this payment method?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private func save() {
        let method = PaymentMethod(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            lastFour: lastFour,
            isDefault: isDefault || !hasExistingDefault
        )
        modelContext.insert(method)
        do {
            try modelContext.save()
            feedbackCenter.success()
            dismiss()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t save payment method")
        }
    }

    private var hasUnsavedChanges: Bool {
        !name.isEmpty || !issuer.isEmpty || !lastFour.isEmpty || type != .card || isDefault != initialDefault
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
        case name
        case issuer
        case lastFour
    }
}
