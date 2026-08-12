import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var symbolName = "calendar.badge.checkmark"

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: symbolName,
            description: Text(message)
        )
        .foregroundStyle(AppTheme.textSecondary)
    }
}
