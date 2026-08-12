# Widget debugging

The WidgetKit extension contains three widget kinds. Use one of the shared
schemes in Xcode so the simulator receives the required `_XCWidgetKind`
environment variable:

- `BillioWidget.MonthlySpending` → `Billio.MonthlySpending`
- `BillioWidget.NextPayment` → `Billio.NextPayment`
- `BillioWidget.UpcomingBills` → `Billio.UpcomingBills`

If Xcode reports `SBAvocadoDebuggingControllerErrorDomain Code=2`, the selected
Widget scheme is missing `_XCWidgetKind`. Select one of the schemes above, or add
the variable manually under Scheme → Run → Arguments → Environment Variables.
