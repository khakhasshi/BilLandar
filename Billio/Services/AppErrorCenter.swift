import Foundation
import Observation

struct UserFacingError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable
@MainActor
final class AppErrorCenter {
    var current: UserFacingError?

    func report(_ error: Error, title: String) {
        current = UserFacingError(title: title, message: error.localizedDescription)
    }

    func report(title: String, message: String) {
        current = UserFacingError(title: title, message: message)
    }
}
