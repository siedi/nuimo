import Testing

@testable import NuimoBar

/// Scenarios for MIDI, `hold` and modes.
@MainActor
struct ControllerMIDITests {
    static let mapping = """
        [settings]
        midi_channel = 1
        midi_cc_per_turn = 127
        midi_relative = "twos"

        [default]
        rotate = "volume"
        press = "media:playpause"
        longtouch_top = "mode:toggle:Resolume"
        touch_top = "mode:Lights"
        touch_bottom = "mode:off"
        fly_left = "mode:Unknown"

        [apps."Resolume Arena"]
        rotate = "midi:cc:20"
        press = "midi:note:36@2"
        double_press = "midi:cc:30"
        swipe_up = "midi:cc:22=64"

        [modes.Resolume]
        rotate = "midi:cc:20"
        rotate_pressed = "midi:cc:21:relative"
        hold = "midi:note:40"
        swipe_right = "midi:note:36"
        fly_left = "midi:pc:0"
        fly_right = "midi:pc:1@3"
        longtouch_top = "mode:toggle:Resolume"

        [modes.Lights]
        hold = "midi:cc:50@4"
        swipe_left = "keys:left"

        [modes.Quiet]
        hold = "none"
        """

    let outputs = RecordingOutputs()
    let scheduler = ManualScheduler()
    let app = AppBox()
    let configBox: ConfigBox
    let controller: Controller

    init() throws {
        let configBox = ConfigBox(config: try Config(parsing: Self.mapping))
        self.configBox = configBox
        controller = Controller(
            outputs: outputs, config: { configBox.config }, frontmostApp: { [app] in app.current },
            scheduler: scheduler)
        app.current = FrontmostApp(name: "Finder", bundleID: "com.apple.finder")
    }

    // MARK: Modes

    @Test func fullTurnInResolumeModeRaisesCC20To127AndStaysThere() {
        controller.activeMode = "Resolume"
        for _ in 0..<10 {
            controller.handle(.rotation(265))
        }
        controller.handle(.rotation(2650))
        let values = outputs.midiMessages.map {
            guard case .controlChange(0, 20, let value) = $0 else { return -1 }
            return Int(value)
        }
        #expect(values.count == 10)
        #expect(values == values.sorted())
        #expect(values.last == 127)
        #expect(outputs.images.last == .level(100))
    }

    @Test func modeAppliesWhileAnotherAppIsInFront() {
        controller.activeMode = "Resolume"
        controller.handle(.gesture(.swipeRight))
        #expect(outputs.calls == [.midi(.noteOn(channel: 0, note: 36, velocity: 127)), .matrix(.arrowRight, 0.8)])
        scheduler.advance(byMilliseconds: 49)
        #expect(outputs.midiMessages.count == 1)
        scheduler.advance(byMilliseconds: 1)
        #expect(outputs.midiMessages.last == .noteOff(channel: 0, note: 36))
    }

    @Test func toggleGestureSwitchesModeOnAndOff() {
        var changes: [String?] = []
        controller.onModeChange = { changes.append($0) }
        controller.handle(.gesture(.longTouchTop))
        #expect(controller.activeMode == "Resolume")
        controller.handle(.gesture(.longTouchTop))
        #expect(controller.activeMode == nil)
        #expect(changes == ["Resolume", nil])
        #expect(outputs.images == [.modeOn, .modeOff])
    }

    @Test func modeOnAndOffActions() {
        controller.handle(.gesture(.touchTop))
        #expect(controller.activeMode == "Lights")
        controller.handle(.gesture(.swipeLeft))
        #expect(outputs.actions == [.keys(KeyShortcut(keyCode: 123, modifiers: []))])
        controller.activeMode = nil
        controller.handle(.gesture(.touchBottom))
        #expect(outputs.images == [.modeOn, .arrowLeft, .modeOff])
    }

    @Test func unknownModeIsIgnored() {
        controller.handle(.gesture(.flyLeft))
        #expect(controller.activeMode == nil)
        #expect(outputs.calls.isEmpty)
    }

    @Test func switchModeFromTheMenu() {
        var changes: [String?] = []
        controller.onModeChange = { changes.append($0) }
        controller.switchMode(to: "Lights")
        controller.switchMode(to: "Lights")
        controller.switchMode(to: nil)
        #expect(changes == ["Lights", nil])
        #expect(outputs.images == [.modeOn, .modeOn, .modeOff])
    }

    @Test func modeRemovedFromTheFileIsOffAtTheNextEvent() throws {
        var changes: [String?] = []
        controller.onModeChange = { changes.append($0) }
        controller.activeMode = "Resolume"
        configBox.config = try Config(parsing: "[default]\npress = \"media:next\"")
        controller.handle(.gesture(.swipeRight))
        #expect(controller.activeMode == nil)
        #expect(changes == [nil])
        #expect(outputs.calls.isEmpty)
    }

    // MARK: hold

    @Test func holdSendsNoteOnAndOffInsteadOfPress() {
        controller.activeMode = "Resolume"
        controller.handle(.button(pressed: true))
        #expect(outputs.calls == [.midi(.noteOn(channel: 0, note: 40, velocity: 127))])
        scheduler.advance(byMilliseconds: 2000)
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 2000)
        #expect(
            outputs.calls == [
                .midi(.noteOn(channel: 0, note: 40, velocity: 127)), .midi(.noteOff(channel: 0, note: 40)),
            ])
    }

    @Test func holdWithControlChangeAndChannel() {
        controller.activeMode = "Lights"
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        #expect(
            outputs.midiMessages == [
                .controlChange(channel: 3, controller: 50, value: 127),
                .controlChange(channel: 3, controller: 50, value: 0),
            ])
    }

    @Test func releaseBelongsToThePressEvenAfterTheModeChanged() {
        controller.activeMode = "Resolume"
        controller.handle(.button(pressed: true))
        controller.activeMode = nil
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 1000)
        #expect(outputs.midiMessages.last == .noteOff(channel: 0, note: 40))
        #expect(!outputs.actions.contains(.media(.playPause)))
    }

    @Test func holdNoneRestoresClickGestures() {
        controller.activeMode = "Quiet"
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 350)
        #expect(outputs.actions == [.media(.playPause)])
    }

    @Test func rotatingWhileHoldingUsesRotatePressedWithRelativeCC() {
        controller.activeMode = "Resolume"
        controller.handle(.button(pressed: true))
        controller.handle(.rotation(-100))
        controller.handle(.rotation(-100))
        controller.handle(.button(pressed: false))
        // 200 of 2650 units at 127 per turn are about 9.6 steps: 4 after the first turn, 5 after the second.
        #expect(
            outputs.midiMessages == [
                .noteOn(channel: 0, note: 40, velocity: 127),
                .controlChange(channel: 0, controller: 21, value: 124),
                .controlChange(channel: 0, controller: 21, value: 123),
                .noteOff(channel: 0, note: 40),
            ])
    }

    @Test func disconnectWhileHoldingReleasesTheNote() {
        controller.activeMode = "Resolume"
        controller.handle(.button(pressed: true))
        controller.reset()
        controller.handle(.button(pressed: false))
        #expect(
            outputs.midiMessages == [.noteOn(channel: 0, note: 40, velocity: 127), .noteOff(channel: 0, note: 40)])
    }

    // MARK: Triggers in an app profile

    @Test func noteTriggerOnOwnChannel() {
        app.current = FrontmostApp(name: "Resolume Arena", bundleID: nil)
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 400)
        #expect(
            outputs.calls == [
                .midi(.noteOn(channel: 1, note: 36, velocity: 127)), .matrix(.smiley, 0.8),
                .midi(.noteOff(channel: 1, note: 36)),
            ])
    }

    @Test func controlChangeTriggerSends127Then0() {
        app.current = FrontmostApp(name: "Resolume Arena", bundleID: nil)
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 50)
        #expect(
            outputs.midiMessages == [
                .controlChange(channel: 0, controller: 30, value: 127),
                .controlChange(channel: 0, controller: 30, value: 0),
            ])
    }

    @Test func fixedValueAndProgramChange() {
        app.current = FrontmostApp(name: "Resolume Arena", bundleID: nil)
        controller.handle(.gesture(.swipeUp))
        controller.activeMode = "Resolume"
        controller.handle(.gesture(.flyLeft))
        controller.handle(.gesture(.flyRight))
        #expect(
            outputs.midiMessages == [
                .controlChange(channel: 0, controller: 22, value: 64),
                .programChange(channel: 0, program: 0),
                .programChange(channel: 2, program: 1),
            ])
        #expect(outputs.images == [.arrowUp, .arrowLeft, .arrowRight])
    }

    @Test func absoluteValueIsKeptAcrossAppAndMode() {
        app.current = FrontmostApp(name: "Resolume Arena", bundleID: nil)
        controller.handle(.rotation(1325))
        controller.activeMode = "Resolume"
        controller.handle(.rotation(1325))
        #expect(
            outputs.midiMessages == [
                .controlChange(channel: 0, controller: 20, value: 64),
                .controlChange(channel: 0, controller: 20, value: 127),
            ])
    }

    @Test func invalidMIDIForEventIsIgnored() throws {
        configBox.config = try Config(
            parsing: """
                [default]
                rotate = "midi:note:36"
                press = "midi:cc:21:relative"
                hold = "midi:pc:1"
                """)
        controller.handle(.rotation(500))
        controller.handle(.button(pressed: true))
        controller.handle(.button(pressed: false))
        scheduler.advance(byMilliseconds: 400)
        #expect(outputs.calls.isEmpty)
    }
}

/// Mapping that a test can replace, like a reloaded file.
@MainActor
final class ConfigBox {
    var config: Config

    init(config: Config) {
        self.config = config
    }
}
