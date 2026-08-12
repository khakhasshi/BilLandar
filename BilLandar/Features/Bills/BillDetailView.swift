import SwiftData
import SwiftUI

struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query(sort: \PaymentRecord.paidAt, order: .reverse) private var payments: [PaymentRecord]
    @Query private var paymentMethods: [PaymentMethod]
    @Query private var allBills: [Bill]
    let bill: Bill
    @State private var showingDeleteConfirmation = false
    @State private var showingEditBill = false
    @State private var showingMarkPaidConfirmation = false
    @State private var editingPayment: PaymentRecord?
    @State private var undoState: PaymentMutationReceipt?

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
                    Text(bill.localizedSubtitle)
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
                    .billandarCard()
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
                    .billandarCard()
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
                        .billandarCard()
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
                            .billandarCard()
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
                                        Button {
                                            editingPayment = payment
                                        } label: {
                                            Image(systemName: "pencil.circle")
                                        }
                                        .billandarTouchTarget()
                                        .accessibilityLabel("Edit \(payment.billName) payment")
                                    }
                                    if payment.status == .pending {
                                        HStack(spacing: 8) {
                                            PaymentStatusButton(title: "Paid", color: AppTheme.success) { update(payment, to: .paid) }
                                            PaymentStatusButton(title: "Failed", color: AppTheme.danger) { update(payment, to: .failed) }
                                            PaymentStatusButton(title: "Refunded", color: Color(hex: "4E89D8")) { update(payment, to: .refunded) }
                                        }
                                    }
                                }
                                .padding(.vertical, 12)
                                if index < min(billPayments.count, 12) - 1 { Divider() }
                            }
                        }
                        .billandarCard(padding: 12)
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
                    Button { showingMarkPaidConfirmation = true } label: {
                        Label("Mark as Paid", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.success))
                }

                switch bill.status {
                case .active:
                    HStack(spacing: 10) {
                        Button("Pause") { setStatus(.paused) }
                            .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.accent))
                        Button("Cancel") { showingDeleteConfirmation = true }
                            .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.danger))
                    }
                case .paused:
                    HStack(spacing: 10) {
                        Button("Resume") { setStatus(.active) }
                            .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.accent))
                        Button("Cancel") { showingDeleteConfirmation = true }
                            .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.danger))
                    }
                case .cancelled:
                    Button("Restore Subscription") { setStatus(.active) }
                        .buttonStyle(BilLandarActionButtonStyle(color: AppTheme.accent))
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .billandarCanvas()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel this bill?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel Bill", role: .destructive) {
                setStatus(.cancelled, dismissAfterSave: true)
            }
        } message: {
            Text("BilLandar will stop including it in upcoming totals and reminders.")
        }
        .alert("Confirm payment?", isPresented: $showingMarkPaidConfirmation) {
            Button("Mark as Paid", action: markAsPaid)
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("BilLandar will record a confirmed payment. You can undo the change immediately afterward.")
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
        .sheet(item: $editingPayment) { PaymentRecordEditView(payment: $0) }
        .safeAreaInset(edge: .bottom) {
            if let undoState {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text(undoState.message)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Undo") { undoPaymentChange() }
                        .font(.subheadline.weight(.bold))
                        .billandarTouchTarget()
                }
                .padding(.horizontal, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(AppTheme.divider.opacity(0.55), lineWidth: 0.7)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undoState.id) {
                    try? await Task.sleep(for: .seconds(6))
                    if self.undoState?.id == undoState.id {
                        withAnimation { self.undoState = nil }
                    }
                }
            }
        }
    }

    private func markAsPaid() {
        do {
            undoState = try PaymentWorkflowService.confirmPayment(
                for: bill,
                payments: billPayments,
                in: modelContext
            )
            feedbackCenter.success()
            Task { await notificationManager.reschedule(for: allBills) }
        } catch {
            modelContext.rollback()
            undoState = nil
            errorCenter.report(error, title: "Couldn’t record payment")
        }
    }

    private func update(_ payment: PaymentRecord, to status: PaymentStatus) {
        do {
            undoState = try PaymentWorkflowService.update(
                payment,
                to: status,
                for: bill,
                in: modelContext
            )
            feedbackCenter.success()
        } catch {
            modelContext.rollback()
            undoState = nil
            errorCenter.report(error, title: "Couldn’t update payment")
        }
    }

    private func setStatus(_ status: BillStatus, dismissAfterSave: Bool = false) {
        bill.status = status
        guard save(title: "Couldn’t update bill status") else { return }
        feedbackCenter.selection()
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

    private func undoPaymentChange() {
        guard let undoState else {
            self.undoState = nil
            return
        }
        do {
            try PaymentWorkflowService.undo(undoState, for: bill, in: modelContext)
            feedbackCenter.selection()
            Task { await notificationManager.reschedule(for: allBills) }
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t undo payment change")
        }
        withAnimation { self.undoState = nil }
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

private struct PaymentStatusButton: View {
    let title: LocalizedStringKey
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTouchSize)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
    }
}

private struct InfoTile: View {
    let title: LocalizedStringKey
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
        .billandarCard(padding: 14)
    }
}

private struct BilLandarActionButtonStyle: ButtonStyle {
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
