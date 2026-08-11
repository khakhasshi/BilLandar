import SwiftData
import SwiftUI

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @State private var searchText = ""
    @State private var selectedStatus: BillStatus?
    @State private var showingAddBill = false
    @State private var editingBill: Bill?
    @State private var billToMarkPaid: Bill?

    private var filteredBills: [Bill] {
        bills.filter { bill in
            let matchesStatus = selectedStatus == nil || bill.status == selectedStatus
            let matchesSearch = searchText.isEmpty
                || bill.name.localizedCaseInsensitiveContains(searchText)
                || bill.subtitle.localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if filteredBills.isEmpty {
                    EmptyStateView(
                        title: "No bills found",
                        message: "Try another filter or add a new bill.",
                        symbolName: "doc.text.magnifyingglass"
                    )
                } else {
                    List {
                        ForEach(filteredBills) { bill in
                            NavigationLink {
                                BillDetailView(bill: bill)
                            } label: {
                                HStack(spacing: 8) {
                                    BillRow(bill: bill)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                    .stroke(AppTheme.divider.opacity(0.45), lineWidth: 0.6)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: AppTheme.horizontalPadding, bottom: 4, trailing: AppTheme.horizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if bill.status != .cancelled {
                                    Button {
                                        billToMarkPaid = bill
                                    } label: {
                                        Label("Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(AppTheme.success)
                                }

                                Button {
                                    togglePause(for: bill)
                                } label: {
                                    Label(
                                        bill.status == .paused ? "Resume" : "Pause",
                                        systemImage: bill.status == .paused ? "play.fill" : "pause.fill"
                                    )
                                }
                                .tint(AppTheme.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingBill = bill
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color(hex: "3E8FDE"))
                            }
                            .contextMenu {
                                Button { editingBill = bill } label: { Label("Edit", systemImage: "pencil") }
                                if bill.status != .cancelled {
                                    Button { billToMarkPaid = bill } label: { Label("Mark as Paid", systemImage: "checkmark.circle") }
                                }
                                Button { togglePause(for: bill) } label: {
                                    Label(bill.status == .paused ? "Resume" : "Pause", systemImage: bill.status == .paused ? "play.fill" : "pause.fill")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 8, for: .scrollContent)
                    .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
                }
            }
            .billioCanvas()
            .billioNavigationTitle("Bills")
            .searchable(text: $searchText, prompt: "Search bills")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddBill = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("Add bill")
                }
            }
            .sheet(isPresented: $showingAddBill) { AddBillView() }
            .sheet(item: $editingBill) { EditBillView(bill: $0) }
            .confirmationDialog(
                "Mark \(billToMarkPaid?.name ?? "bill") as paid?",
                isPresented: Binding(
                    get: { billToMarkPaid != nil },
                    set: { if !$0 { billToMarkPaid = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Confirm Payment") {
                    if let billToMarkPaid { markPaid(billToMarkPaid) }
                    billToMarkPaid = nil
                }
                Button("Not Now", role: .cancel) { billToMarkPaid = nil }
            } message: {
                Text("This records a confirmed payment and updates the next due date.")
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", count: bills.count, selected: selectedStatus == nil) {
                    selectedStatus = nil
                }
                ForEach(BillStatus.allCases) { status in
                FilterChip(
                        title: LocalizedStringKey(status.title),
                        count: bills.filter { $0.status == status }.count,
                        selected: selectedStatus == status
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 10)
        }
    }
}

private struct FilterChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    let title: LocalizedStringKey
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            feedbackCenter.selection()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)")
                    .opacity(0.7)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(selected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? AppTheme.accent : AppTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: AppTheme.minimumTouchSize)
        .contentShape(Capsule())
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(count)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selected)
    }
}

private extension BillsView {
    func togglePause(for bill: Bill) {
        bill.status = bill.status == .paused ? .active : .paused
        do {
            try modelContext.save()
            feedbackCenter.selection()
            Task { await notificationManager.reschedule(for: bills) }
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t update bill")
        }
    }

    func markPaid(_ bill: Bill) {
        do {
            _ = try PaymentWorkflowService.confirmPayment(
                for: bill,
                payments: payments,
                in: modelContext
            )
            feedbackCenter.success()
            Task { await notificationManager.reschedule(for: bills) }
        } catch {
            modelContext.rollback()
            errorCenter.report(error, title: "Couldn’t record payment")
        }
    }
}
