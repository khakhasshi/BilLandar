import SwiftData
import SwiftUI

struct NotificationsView: View {
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @State private var filter = NotificationFilter.all

    private var upcomingBills: [Bill] {
        let endDate = Calendar.billandar.date(byAdding: .day, value: 7, to: .now) ?? .now
        return bills.filter {
            $0.status == .active
                && $0.nextDueDate >= Date.now.startOfDay
                && $0.nextDueDate <= endDate
        }
    }

    private var updates: [BillInsight] {
        InsightEngine.generate(bills: bills, payments: payments)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Notification filter", selection: $filter) {
                    ForEach(NotificationFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: filter) { _, _ in feedbackCenter.selection() }

                if filter != .updates {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reminders")
                            .font(.headline)
                            .padding(.bottom, 4)

                        if upcomingBills.isEmpty {
                            emptyMessage("No upcoming reminders")
                        } else {
                            ForEach(Array(upcomingBills.enumerated()), id: \.element.id) { index, bill in
                                NavigationLink {
                                    BillDetailView(bill: bill)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        BillIcon(bill: bill, size: 38)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(bill.name).font(.subheadline.weight(.semibold))
                                            Text(notificationText(for: bill)).font(.caption)
                                            Text(reminderDate(for: bill), format: .dateTime.month(.abbreviated).day().hour().minute())
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        Circle().fill(AppTheme.danger).frame(width: 6, height: 6).padding(.top, 8)
                                    }
                                    .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)
                                if index < upcomingBills.count - 1 { Divider().padding(.leading, 50) }
                            }
                        }
                    }
                    .billandarCard()
                }

                if filter != .reminders {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Updates").font(.headline)
                        if updates.isEmpty {
                            emptyMessage("No subscription updates")
                        } else {
                            ForEach(updates) { insight in
                                if let bill = bills.first(where: { $0.id == insight.billIDs.first }) {
                                    NavigationLink {
                                        BillDetailView(bill: bill)
                                    } label: {
                                        InsightCard(insight: insight, showsChevron: true)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    InsightCard(insight: insight)
                                }
                            }
                        }
                    }
                }

                NavigationLink {
                    ReminderSettingsView()
                } label: {
                    Label("Reminder Settings", systemImage: "bell.badge")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppTheme.minimumTouchSize)
                        .padding(.vertical, 13)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 24)
            .billandarTabBarClearance()
        }
        .billandarCanvas()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func notificationText(for bill: Bill) -> String {
        let days = Calendar.billandar.dateComponents([.day], from: .now.startOfDay, to: bill.nextDueDate.startOfDay).day ?? 0
        let due: String
        if days <= 0 {
            due = String(localized: "today", locale: BilLandarSharedStore.appLocale)
        } else if days == 1 {
            due = String(localized: "tomorrow", locale: BilLandarSharedStore.appLocale)
        } else {
            due = String(
                format: String(localized: "in %lld days", locale: BilLandarSharedStore.appLocale),
                days
            )
        }
        let amount = bill.amount.formatted(.currency(code: bill.currencyCode).locale(BilLandarSharedStore.appLocale))
        return String(
            format: String(localized: "%@ is due %@", locale: BilLandarSharedStore.appLocale),
            amount,
            due
        )
    }

    private func reminderDate(for bill: Bill) -> Date {
        notificationManager.reminderFireDate(for: bill)
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
    }
}

private enum NotificationFilter: CaseIterable, Identifiable {
    case all
    case reminders
    case updates

    var id: Self { self }
    var title: String {
        switch self {
        case .all: "All"
        case .reminders: "Reminders"
        case .updates: "Updates"
        }
    }
}

private struct ReminderSettingsView: View {
    @Environment(NotificationManager.self) private var notificationManager
    @Query private var bills: [Bill]

    var body: some View {
        Form {
            Section {
                Toggle("Bill reminders", isOn: notificationBinding)
                LabeledContent("Permission", value: notificationManager.authorizationState.title)
                LabeledContent("Scheduled", value: "\(notificationManager.pendingReminderCount)")
                if let lastError = notificationManager.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                }
            } footer: {
                Text("Each active bill uses its own reminder lead time. iOS may adjust delivery timing based on system settings.")
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notificationManager.refreshStatus() }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: {
                notificationManager.isEnabled
                    && (notificationManager.authorizationState == .authorized
                        || notificationManager.authorizationState == .provisional)
            },
            set: { enabled in
                Task {
                    if enabled {
                        _ = await notificationManager.enableAndRequestAuthorization(for: bills)
                    } else {
                        await notificationManager.disable()
                    }
                }
            }
        )
    }
}
