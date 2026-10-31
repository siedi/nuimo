/// Turns press and release of the Nuimo's button into short, long and double presses.
///
/// A press that was held long or used for rotating does not count as a click. A short press is only reported
/// after ``doublePressGap``, because a second press could still follow.
@MainActor
final class ButtonGestures {
    /// Time the button has to be held until a press counts as long.
    static let longPressDelay: Duration = .milliseconds(400)
    /// Time to wait for a second press.
    static let doublePressGap: Duration = .milliseconds(350)

    /// Whether the button is currently held down.
    private(set) var isPressed = false

    private let scheduler: any Scheduler
    private let emit: @MainActor (Gesture) -> Void
    private var isConsumed = false
    private var clicks = 0
    private var longPressTimer: ScheduledAction?
    private var clickTimer: ScheduledAction?

    init(scheduler: any Scheduler, emit: @escaping @MainActor (Gesture) -> Void) {
        self.scheduler = scheduler
        self.emit = emit
    }

    func press() {
        isPressed = true
        isConsumed = false
        clickTimer?.cancel()
        clickTimer = nil
        longPressTimer?.cancel()
        longPressTimer = scheduler.schedule(after: Self.longPressDelay) { [weak self] in
            self?.longPressElapsed()
        }
    }

    func release() {
        guard isPressed else { return }
        isPressed = false
        longPressTimer?.cancel()
        longPressTimer = nil
        guard !isConsumed else { return }
        clicks += 1
        if clicks == 2 {
            clicks = 0
            emit(.doublePress)
        } else {
            clickTimer = scheduler.schedule(after: Self.doublePressGap) { [weak self] in
                self?.clickGapElapsed()
            }
        }
    }

    /// Call on every rotation; rotating while pressed cancels the click.
    func rotated() {
        if isPressed && !isConsumed {
            consume()
        }
    }

    /// Forgets the current state, e.g. after the connection was lost.
    func reset() {
        longPressTimer?.cancel()
        clickTimer?.cancel()
        longPressTimer = nil
        clickTimer = nil
        isPressed = false
        isConsumed = false
        clicks = 0
    }

    private func longPressElapsed() {
        longPressTimer = nil
        consume()
        emit(.longPress)
    }

    private func clickGapElapsed() {
        clickTimer = nil
        clicks = 0
        emit(.press)
    }

    private func consume() {
        isConsumed = true
        clicks = 0
        longPressTimer?.cancel()
        longPressTimer = nil
    }
}
