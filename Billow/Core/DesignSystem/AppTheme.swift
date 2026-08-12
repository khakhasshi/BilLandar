import SwiftUI
import UIKit

enum AppTheme {
    static let accent = adaptive(light: "7357F6", dark: "9A88FF")
    static let accentSoft = adaptive(light: "EFEAFF", dark: "29233F")
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let divider = Color(uiColor: .separator)
    static let success = adaptive(light: "278A62", dark: "5BD6A0")
    static let warning = adaptive(light: "B56A00", dark: "FFB84D")
    static let danger = adaptive(light: "D83B58", dark: "FF7086")

    static let cardRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 18
    static let minimumTouchSize: CGFloat = 44
    static let tabBarClearance: CGFloat = 64

    private static func adaptive(light: String, dark: String) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
            }
        )
    }
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
    func billowCard(padding: CGFloat = 16) -> some View {
        modifier(BillowCardModifier(padding: padding))
    }

    func billowCanvas() -> some View {
        self.background(AppTheme.canvas.ignoresSafeArea())
    }

    func billowTouchTarget() -> some View {
        frame(minWidth: AppTheme.minimumTouchSize, minHeight: AppTheme.minimumTouchSize)
            .contentShape(Rectangle())
    }

    func billowTabBarClearance() -> some View {
        safeAreaPadding(.bottom, AppTheme.tabBarClearance)
    }

    func billowNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

private struct BillowCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(
                        AppTheme.divider.opacity(accessibilityContrast == .increased ? 0.85 : 0.42),
                        lineWidth: accessibilityContrast == .increased ? 1.2 : 0.6
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.045),
                radius: colorScheme == .dark ? 3 : 7,
                y: colorScheme == .dark ? 1 : 3
            )
    }
}
