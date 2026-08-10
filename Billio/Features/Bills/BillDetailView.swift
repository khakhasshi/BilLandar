import SwiftData
import SwiftUI

struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Query(sort: \PaymentRecord.paidAt, order: .reverse) private var payments: [PaymentRecord]
    @Query private var paymentMethods: [PaymentMethod]
    @Query private var allBills: [Bill]
    let bill: Bill
    @State private var showingDeleteConfirmation = false
    @State private var showingEditBill = false

    private var billPayments: [PaymentRecord] {
        payments.filter { $0.billID == bill.id }
    }

    private var paymentMethod: PaymentMethod? {
        guard let paymentMethodID = bill.paymentMethodID else { return nil }
        return paymentMethods.first { $0.id == paymentMethodID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    BillIcon(bill: bill, size: 72)
                    Text(bill.name)
                        .font(.title2.bold())
                    Text(bill.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    InfoTile(title: "Amount", value: bill.amount.formatted(.currency(code: bill.currencyCode)))
                    InfoTile(title: "Billing cycle", value: bill.cycle.title)
                    InfoTile(
                        title: "Next due date",
                        value: bill.nextDueDate.formatted(.dateTime.month(.abbreviated).day().year()),
                        valueColor: AppTheme.danger
                    )
                    InfoTile(title: "Status", value: bill.status.title, valueColor: billStatusColor)
                }

                if let trialEndDate = bill.trialEndDate {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .foregroundStyle(AppTheme.warning)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Free trial")
                                .font(.subheadline.weight(.semibold))
                            Text("Converts on \(trialEndDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .billioCard()
                }

                if bill.currencyCode != exchangeRates.displayCurrency,
                   let converted = exchangeRates.convert(bill.amount, from: bill.currencyCode) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reference amount")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(converted, format: .currency(code: exchangeRates.displayCurrency))
                                .font(.headline)
                        }
                        Spacer()
                        Text(exchangeRates.dataStatusText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .billioCard()
                }

                if paymentMethod != nil || !bill.paymentMethodLabel.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment method")
                            .font(.headline)
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text(paymentMethod?.displayName ?? bill.paymentMethodLabel)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .billioCard()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(.headline)
                    if billPayments.isEmpty {
                        Text("No payments recorded yet")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .billioCard()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(billPayments.prefix(12).enumerated()), id: \.element.id) { index, payment in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(payment.dueDate, format: .dateTime.month(.abbreviated).day().year())
                                                .font(.subheadline)
                                            Text(payment.status == .pending ? "Due date" : "Payment date")
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        Text(payment.amount, format: .currency(code: payment.currencyCode))
                                            .font(.subheadline.weight(.semibold))
                                        Text(payment.status.title)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(statusColor(payment.status))
                                    }
                                    if payment.status == .pending {
                                        HStack {
                                            Button("Paid") { update(payment, to: .paid) }
                                            Button("Failed") { update(payment, to: .failed) }
                                            Button("Refunded") { update(payment, to: .refunded) }
                                        }
                                        .font(.caption.weight(.semibold))
                                    }
                                }
                                .padding(.vertical, 12)
                                if index < min(billPayments.count, 12) - 1 { Divider() }
                            }
                        }
                        .billioCard(padding: 12)
                    }
                }

                if let cancellationURL = bill.cancellationURL {
                    VStack(spacing: 7) {
                        Link(destination: cancellationURL) {
                            Label("Open cancellation page", systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                        }
                        Label(
                            bill.cancellationURLVerified ? "Verified merchant domain" : "User-provided link · verify before signing in",
                            systemImage: bill.cancellationURLVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(bill.cancellationURLVerified ? AppTheme.success : AppTheme.warning)
                    }
                }

                if bill.status != .cancelled {
                    Button(action: markAsPaid) {
                        Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(BillioActionButtonStyle(color: AppTheme.success))
                }

                switch bill.status {
                case .active:
                    HStack(spacing: 10) {
                        Button("Pause") { setStatus(.paused) }
                            .buttonStyle(BillioActionButtonStyle(color: AppTheme.accent))
                        Button("Cancel") { showingDeleteConfirmation = true }
                            .buttonStyle(BillioActionButtonStyle(color: AppTheme.danger))
                    }
                case .paused:
                    HStack(spacing: 10) {
                        Button("Resume") { setStatus(.active) }
                            .buttonStyle(BillioActionButtonStyle(color: AppTheme.accent))
                        Button("Cancel") { showingDeleteConfirmation = true }
                            .buttonStyle(BillioActionButtonStyle(color: AppTheme.danger))
                    }
                case .cancelled:
                    Button("Restore Subscription") { setStatus(.active) }
                        .buttonStyle(BillioActionButtonStyle(color: AppTheme.accent))
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .billioCanvas()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Cancel this bill?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Cancel Bill", role: .destructive) {
                setStatus(.cancelled, dismissAfterSave: true)
            }
        } message: {
            Text("Billio will stop including it in upcoming totals and reminders.")
        }
        .task {
            await exchangeRates.refreshIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditBill = true }
            }
        }
        .sheet(isPresented: $showingEditBill) { EditBillView(bill: bill) }
    }

    private func markAsPaid() {
        if let pending = billPayments.first(where: { $0.status == .pending }) {
            pending.status = .paid
            pending.paidAt = .now
            pending.note = "Confirmed manually"
        } else {
            let payment = PaymentRecord(
                billID: bill.id,
                billName: bill.name,
                amount: bill.amount,
                currencyCode: bill.currencyCode,
                paidAt: .now,
                dueDate: bill.nextDueDate,
                status: .paid,
                note: "Confirmed manually"
            )
            modelContext.insert(payment)
            bill.nextDueDate = bill.renewalDate(after: bill.nextDueDate)
        }
        bill.trialEndDate = nil
        bill.updatedAt = .now
        if save(title: "Couldn’t record payment") {
            Task { await notificationManager.reschedule(for: allBills) }
        }
    }

    private func update(_ payment: PaymentRecord, to status: PaymentStatus) {
        payment.status = status
        if status == .paid { payment.paidAt = .now }
        payment.note = "Updated manually"
        _ = save(title: "Couldn’t update payment")
    }

    private func setStatus(_ status: BillStatus, dismissAfterSave: Bool = false) {
        bill.status = status
        guard save(title: "Couldn’t update bill status") else { return }
        Task {
            if status == .active {
                await notificationManager.reschedule(for: allBills)
            } else {
                await notificationManager.cancelReminder(for: bill.id)
            }
        }
        if dismissAfterSave { dismiss() }
    }

    @discardableResult
    private func save(title: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: title)
            return false
        }
    }

    private func statusColor(_ status: PaymentStatus) -> Color {
        switch status {
        case .paid: AppTheme.success
        case .pending: AppTheme.warning
        case .failed: AppTheme.danger
        case .refunded: Color(hex: "4E89D8")
        }
    }

    private var billStatusColor: Color {
        switch bill.status {
        case .active: AppTheme.success
        case .paused: AppTheme.warning
        case .cancelled: AppTheme.danger
        }
    }
}

private struct InfoTile: View {
    let title: String
    let value: String
    var valueColor = AppTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 60, alignment: .top)
        .billioCard(padding: 14)
    }
}

private struct BillioActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(color.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
