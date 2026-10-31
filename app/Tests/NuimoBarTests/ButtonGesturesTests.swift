import Testing

@testable import NuimoBar

@MainActor
struct ButtonGesturesTests {
    let scheduler = ManualScheduler()
    let recorder = GestureRecorder()
    let button: ButtonGestures

    init() {
        button = ButtonGestures(scheduler: scheduler) { [recorder] in recorder.gestures.append($0) }
    }

    @Test func shortPressIsReportedAfterTheGap() {
        button.press()
        scheduler.advance(byMilliseconds: 100)
        button.release()
        scheduler.advance(byMilliseconds: 349)
        #expect(recorder.gestures.isEmpty)
        scheduler.advance(byMilliseconds: 1)
        #expect(recorder.gestures == [.press])
    }

    @Test func doublePressWithinTheGap() {
        button.press()
        button.release()
        scheduler.advance(byMilliseconds: 300)
        button.press()
        button.release()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures == [.doublePress])
    }

    @Test func twoPressesFurtherApartAreTwoShortPresses() {
        button.press()
        button.release()
        scheduler.advance(byMilliseconds: 400)
        button.press()
        button.release()
        scheduler.advance(byMilliseconds: 400)
        #expect(recorder.gestures == [.press, .press])
    }

    @Test func longPressFiresWhileHeldAndReleaseAddsNothing() {
        button.press()
        scheduler.advance(byMilliseconds: 399)
        #expect(recorder.gestures.isEmpty)
        scheduler.advance(byMilliseconds: 1)
        #expect(recorder.gestures == [.longPress])
        button.release()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures == [.longPress])
    }

    @Test func rotatingWhilePressedSuppressesClickAndLongPress() {
        button.press()
        scheduler.advance(byMilliseconds: 100)
        button.rotated()
        scheduler.advance(byMilliseconds: 1000)
        button.release()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures.isEmpty)
    }

    @Test func rotatingWhileReleasedDoesNotInterfere() {
        button.rotated()
        button.press()
        button.release()
        button.rotated()
        scheduler.advance(byMilliseconds: 350)
        #expect(recorder.gestures == [.press])
    }

    @Test func longSecondPressReplacesThePendingClick() {
        // Same as nuimo.py: the first click is dropped when the second press becomes long.
        button.press()
        button.release()
        scheduler.advance(byMilliseconds: 200)
        button.press()
        scheduler.advance(byMilliseconds: 400)
        button.release()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures == [.longPress])
    }

    @Test func releaseWithoutPressIsIgnored() {
        button.release()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures.isEmpty)
        #expect(!button.isPressed)
    }

    @Test func resetDropsPendingGestures() {
        button.press()
        button.release()
        button.reset()
        scheduler.advance(byMilliseconds: 1000)
        #expect(recorder.gestures.isEmpty)
    }

    @Test func isPressedFollowsTheButton() {
        button.press()
        #expect(button.isPressed)
        button.release()
        #expect(!button.isPressed)
    }
}

@MainActor
final class GestureRecorder {
    var gestures: [Gesture] = []
}
