import SwiftUI
import WidgetKit

@main
struct BillioWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPaymentWidget()
        MonthlySpendingWidget()
        UpcomingBillsWidget()
    }
}
