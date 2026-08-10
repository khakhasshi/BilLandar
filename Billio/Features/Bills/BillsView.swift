import SwiftData
import SwiftUI

struct BillsView: View {
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @State private var searchText = ""
    @State private var selectedStatus: BillStatus?
    @State private var showingAddBill = false

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
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredBills) { bill in
                                NavigationLink {
                                    BillDetailView(bill: bill)
                                } label: {
                                    BillRow(bill: bill)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)

                                if bill.id != filteredBills.last?.id {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .billioCard(padding: 12)
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .billioCanvas()
            .navigationTitle("Bills")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search bills")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddBill = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("Add bill")
                }
            }
            .sheet(isPresented: $showingAddBill) { AddBillView() }
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
                        title: status.title,
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
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}
