import Observation

@Observable
@MainActor
final class AppFeedbackCenter {
    private(set) var selectionEvent = 0
    private(set) var successEvent = 0
    private(set) var warningEvent = 0

    func selection() { selectionEvent += 1 }
    func success() { successEvent += 1 }
    func warning() { warningEvent += 1 }
}
