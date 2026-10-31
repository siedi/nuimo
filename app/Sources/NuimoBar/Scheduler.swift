/// Runs actions after a delay on the main actor. Injected so tests can control time.
@MainActor
protocol Scheduler {
    /// Schedules `action` to run once after `delay`. The returned handle cancels it.
    @discardableResult
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> ScheduledAction
}

/// Handle for an action scheduled with a ``Scheduler``.
@MainActor
final class ScheduledAction {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// Prevents the action from running. Calling it again or after the action ran has no effect.
    func cancel() {
        onCancel?()
        onCancel = nil
    }
}
