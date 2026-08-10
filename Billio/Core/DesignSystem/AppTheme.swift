import SwiftUI

enum AppTheme {
    static let accent = Color(hex: "7357F6")
    static let accentSoft = Color(hex: "EFEAFF")
    static let canvas = Color(hex: "F7F6FC")
    static let card = Color.white
    static let textPrimary = Color(hex: "171625")
    static let textSecondary = Color(hex: "85829B")
    static let divider = Color(hex: "EEEAF7")
    static let success = Color(hex: "43B783")
    static let warning = Color(hex: "F5A43A")
    static let danger = Color(hex: "F25970")

    static let cardRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 18
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 8:
            red = value >> 24
            green = value >> 16 & 0xFF
            blue = value >> 8 & 0xFF
            alpha = value & 0xFF
        default:
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
            alpha = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

extension View {
    func billioCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: Color.black.opacity(0.025), radius: 10, y: 3)
    }

    func billioCanvas() -> some View {
        self.background(AppTheme.canvas.ignoresSafeArea())
    }
}
