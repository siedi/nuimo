/// ``Scheduler`` backed by real time, using tasks on the main actor.
@MainActor
struct MainScheduler: Scheduler {
    @discardableResult
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> ScheduledAction {
        let task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
        return ScheduledAction { task.cancel() }
    }
}
