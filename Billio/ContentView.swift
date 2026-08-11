import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(AppFeedbackCenter.self) private var feedbackCenter

    var body: some View {
        RootTabView()
            .alert(item: errorBinding) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sensoryFeedback(.error, trigger: errorCenter.current?.id)
            .sensoryFeedback(.selection, trigger: feedbackCenter.selectionEvent)
            .sensoryFeedback(.success, trigger: feedbackCenter.successEvent)
            .sensoryFeedback(.warning, trigger: feedbackCenter.warningEvent)
    }

    private var errorBinding: Binding<UserFacingError?> {
        Binding(
            get: { errorCenter.current },
            set: { errorCenter.current = $0 }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bill.self, PaymentRecord.self, PaymentMethod.self], inMemory: true)
        .environment(ExchangeRateStore())
        .environment(CloudSyncMonitor(usesCloudKitStore: false))
        .environment(NotificationManager())
        .environment(AppErrorCenter())
        .environment(AppFeedbackCenter())
        .environment(ThemeStore())
        .environment(AppLanguageStore())
}
