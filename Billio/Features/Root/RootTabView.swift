import SwiftData
import SwiftUI
import WidgetKit

enum AppTab: Hashable {
    case overview
    case calendar
    case bills
    case analytics
    case settings
}

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(CloudSyncMonitor.self) private var cloudSync
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter
    @Environment(ExchangeRateStore.self) private var exchangeRates
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    @Query private var payments: [PaymentRecord]
    @State private var selection: AppTab = .overview

    var body: some View {
        TabView(selection: $selection) {
            OverviewView()
                .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.overview)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            BillsView()
                .tabItem { Label("Bills", systemImage: "list.bullet.clipboard.fill") }
                .tag(AppTab.bills)

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                .tag(AppTab.analytics)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.accent)
        .onChange(of: selection) { _, _ in feedbackCenter.selection() }
        .onChange(of: widgetDataRevision) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .task {
            await notificationManager.refreshStatus()
            reconcileBills()
            await notificationManager.reschedule(for: bills)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .task { await cloudSync.monitorEvents() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await notificationManager.refreshStatus()
                reconcileBills()
                await notificationManager.reschedule(for: bills)
            }
        }
    }

    private var widgetDataRevision: String {
        let billRevision = bills
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.updatedAt.timeIntervalSinceReferenceDate)|\($0.statusRawValue)|\($0.nextDueDate.timeIntervalSinceReferenceDate)"
            }
            .joined(separator: ";")
        let paymentRevision = payments
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                "\($0.id.uuidString)|\($0.statusRawValue)|\($0.amount)|\($0.paidAt.timeIntervalSinceReferenceDate)"
            }
            .joined(separator: ";")
        let rateRevision = exchangeRates.snapshot?.fetchedAt.timeIntervalSinceReferenceDate ?? 0
        return "\(billRevision)#\(paymentRevision)#\(exchangeRates.displayCurrency)#\(rateRevision)"
    }

    private func reconcileBills() {
        do {
            try BillLifecycleService.reconcile(
                bills: bills,
                payments: payments,
                in: modelContext
            )
        } catch {
            errorCenter.report(error, title: "Couldn’t update billing cycles")
        }
    }
}
