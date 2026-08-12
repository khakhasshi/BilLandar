import SwiftUI
import WidgetKit

@main
struct BillowWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPaymentWidget()
        MonthlySpendingWidget()
        UpcomingBillsWidget()
    }
}
