import SwiftUI
import WidgetKit

@main
struct BilLandarWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPaymentWidget()
        MonthlySpendingWidget()
        UpcomingBillsWidget()
    }
}
