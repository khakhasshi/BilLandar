import SwiftData
import SwiftUI

struct PaymentMethodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppErrorCenter.self) private var errorCenter
    @Query(sort: \PaymentMethod.createdAt) private var methods: [PaymentMethod]
    @Query private var bills: [Bill]
    @State private var showingAddMethod = false

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
                    .swipeActions {
                        Button("Delete", role: .destructive) { delete(method) }
                        if !method.isDefault {
                            Button("Default") { makeDefault(method) }
                                .tint(AppTheme.accent)
                        }
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
    let hasExistingDefault: Bool

    @State private var name = ""
    @State private var issuer = ""
    @State private var lastFour = ""
    @State private var type: PaymentMethodType = .card
    @State private var isDefault = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Personal Visa", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(PaymentMethodType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Issuer (optional)", text: $issuer)
                    TextField("Last four digits (optional)", text: $lastFour)
                        .keyboardType(.numberPad)
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
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isDefault = !hasExistingDefault }
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
            dismiss()
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t save payment method")
        }
    }
}
