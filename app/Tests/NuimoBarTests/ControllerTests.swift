import Testing

@testable import NuimoBar

/// Scenarios without a device: input in, recorded outputs out.
@MainActor
struct ControllerTests {
    static let mapping = """
        [settings]
        scroll_speed = 0.5
        rotate_step = 300

        [default]
        rotate = "volume"
        press = "media:playpause"
        double_press = "media:mute"
        swipe_left = "media:previous"
        swipe_right = "media:next"
        longtouch_top = "shell:say hallo"

        [apps.TradingView]
        rotate = "scroll"
        press = "keys:opt+return"
        swipe_right = "keys:tab"
        swipe_left = "keys:shift+tab"
        swipe_up = "none"

        [apps.Preview]
        rotate_left = "keys:left"
        rotate_right = "keys:right"
        rotate_pressed = "scroll:cmd"
        """

    let outputs = RecordingOutputs()
    let scheduler = ManualScheduler()
    let app = AppBox()
    let controller: Controller

    init() throws {
        let config = try Config(parsing: Self.mapping)
        controller = Controller(
            outputs: outputs, config: { config }, frontmostApp: { [app] in app.current }, scheduler: scheduler)
    }

    func click() {
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
    }

    @Test func finderShortPressTogglesPlayback() {
        app.current = FrontmostApp(name: "Finder", bundleID: "com.apple.finder")
        click()
        #expect(outputs.calls.isEmpty)
        scheduler.advance(byMilliseconds: 350)
        #expect(outputs.calls == [.media(.playPause), .matrix(.smiley, 0.8)])
    }

    @Test func tradingViewShortPressSendsOptionReturn() {
        app.current = FrontmostApp(name: "TradingView", bundleID: nil)
        click()
        scheduler.advance(byMilliseconds: 350)
        #expect(outputs.actions == [.keys(KeyShortcut(keyCode: 36, modifiers: .option))])
    }

    @Test func doublePressWithinTheGapIsOnlyADoublePress() {
        click()
        scheduler.advance(byMilliseconds: 200)
        click()
        scheduler.advance(byMilliseconds: 1000)
        #expect(outputs.calls == [.media(.mute), .matrix(.twoDots, 0.8)])
    }

    @Test func noneInAppProfileStopsTheFallback() {
        app.current = FrontmostApp(name: "TradingView", bundleID: nil)
        controller.handle(.gesture(.swipeUp))
        #expect(outputs.calls.isEmpty)
    }

    @Test func eventMissingInAppProfileFallsBackToStandard() {
        app.current = FrontmostApp(name: "TradingView", bundleID: nil)
        controller.handle(.gesture(.longTouchTop))
        #expect(outputs.calls == [.shell("say hallo"), .matrix(.dotTop, 0.8)])
    }

    @Test func unmappedEventDoesNothingAndIsReported() {
        var reported: [Controller.Activity] = []
        controller.onActivity = { reported.append($0) }
        controller.handle(.gesture(.flyLeft))
        #expect(outputs.calls.isEmpty)
        #expect(reported == [Controller.Activity(event: "fly_left", action: nil, profile: .standard)])
    }

    @Test func activityNamesTheAppProfile() {
        var reported: [Controller.Activity] = []
        controller.onActivity = { reported.append($0) }
        app.current = FrontmostApp(name: "TradingView", bundleID: nil)
        controller.handle(.gesture(.swipeRight))
        #expect(
            reported == [Controller.Activity(event: "swipe_right", action: "keys:tab", profile: .app("TradingView"))])
    }

    @Test func rotatingChangesVolumeAndShowsTheLevel() {
        controller.handle(.rotation(265))
        #expect(outputs.calls == [.volume(10), .matrix(.level(60), 1.5)])
    }

    @Test func volumeWithoutControlShowsNothing() {
        outputs.volume = nil
        controller.handle(.rotation(265))
        #expect(outputs.images.isEmpty)
    }

    @Test func tradingViewRotationScrolls() {
        app.current = FrontmostApp(name: "TradingView", bundleID: nil)
        controller.handle(.rotation(-40))
        controller.handle(.rotation(1))
        #expect(outputs.calls == [.scroll(-20, [])])
    }

    @Test func rotationStepsKeepTheRest() {
        app.current = FrontmostApp(name: "Preview", bundleID: nil)
        let right = KeyShortcut(keyCode: 124, modifiers: [])
        let left = KeyShortcut(keyCode: 123, modifiers: [])
        controller.handle(.rotation(250))
        #expect(outputs.calls.isEmpty)
        controller.handle(.rotation(400))
        #expect(outputs.calls == [.keys(right), .keys(right)])
        controller.handle(.rotation(-100))
        controller.handle(.rotation(-400))
        #expect(outputs.calls == [.keys(right), .keys(right), .keys(left)])
    }

    @Test func rotatingWhilePressedUsesRotatePressedAndSuppressesTheClick() {
        app.current = FrontmostApp(name: "Preview", bundleID: nil)
        controller.handle(.button(pressed: true))
        controller.handle(.rotation(100))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 1000)
        #expect(outputs.calls == [.scroll(50, .command)])
    }

    @Test func rotatePressedWithoutMappingDoesNothing() {
        controller.handle(.button(pressed: true))
        controller.handle(.rotation(100))
        #expect(outputs.calls.isEmpty)
    }

    @Test func longPressWithoutMappingShowsNoImage() {
        controller.handle(.button(pressed: true))
        scheduler.advance(byMilliseconds: 400)
        controller.handle(.button(pressed: false))
        #expect(outputs.calls.isEmpty)
    }

    @Test func invalidActionsDoNothing() throws {
        let config = try Config(
            parsing: """
                [default]
                press = "volume"
                swipe_left = "keys:hyper+a"
                rotate = "keys:a"
                """)
        let controller = Controller(outputs: outputs, config: { config }, frontmostApp: { nil }, scheduler: scheduler)
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 350)
        controller.handle(.gesture(.swipeLeft))
        controller.handle(.rotation(300))
        #expect(outputs.calls.isEmpty)
    }

    @Test func resetDropsAPendingClick() {
        click()
        controller.reset()
        scheduler.advance(byMilliseconds: 1000)
        #expect(outputs.calls.isEmpty)
    }
}

/// The app in front, changeable during a test.
@MainActor
final class AppBox {
    var current: FrontmostApp?
}
