import SwiftUI

struct BillIcon: View {
    let bill: Bill
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: bill.symbolName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: bill.brandColorHex), in: RoundedRectangle(cornerRadius: size * 0.25))
            .accessibilityHidden(true)
    }
}
