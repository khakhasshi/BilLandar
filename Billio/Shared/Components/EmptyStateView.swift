import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
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
