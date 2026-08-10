import SwiftData
import SwiftUI

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
        .task {
            await notificationManager.refreshStatus()
            reconcileBills()
            await notificationManager.reschedule(for: bills)
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
