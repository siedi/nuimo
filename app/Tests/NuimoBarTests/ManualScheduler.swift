@testable import NuimoBar

/// ``Scheduler`` for tests: time only moves on ``advance(by:)``.
@MainActor
final class ManualScheduler: Scheduler {
    private struct Entry {
        let id: Int
        let due: Duration
        let action: @MainActor () -> Void
    }

    private(set) var now: Duration = .zero
    private var entries: [Entry] = []
    private var nextID = 0

    @discardableResult
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> ScheduledAction {
        let id = nextID
        nextID += 1
        entries.append(Entry(id: id, due: now + delay, action: action))
        return ScheduledAction { [weak self] in
            self?.entries.removeAll { $0.id == id }
        }
    }

    /// Moves time forward and runs every action that becomes due, in order of due time.
    func advance(by duration: Duration) {
        let end = now + duration
        while let next = entries.filter({ $0.due <= end }).min(by: { ($0.due, $0.id) < ($1.due, $1.id) }) {
            entries.removeAll { $0.id == next.id }
            now = next.due
            next.action()
        }
        now = end
    }

    func advance(byMilliseconds milliseconds: Int) {
        advance(by: .milliseconds(milliseconds))
    }
}
