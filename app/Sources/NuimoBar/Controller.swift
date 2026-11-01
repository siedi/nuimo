/// Turns input from the Nuimo into actions: event → profile → action.
///
/// Profiles are searched in the order active mode, app in front, standard. The first profile that contains
/// the event decides; `none` silences it without falling back. For rotation, the first profile with either
/// `rotate` or `rotate_left`/`rotate_right` decides.
///
/// If `hold` is mapped when the button goes down, press and release trigger it directly and the click
/// gestures are off for that press.
@MainActor
final class Controller {
    /// What happened with an event, for the menu.
    struct Activity: Equatable, Sendable {
        var event: String
        /// The action text, or `nil` if no profile maps the event.
        var action: String?
        /// The profile that applies: mode, app or standard.
        var profile: Profile.Kind
    }

    /// Delay between the two halves of a MIDI trigger: Note Off after Note On, CC 0 after CC 127.
    static let midiTriggerLength: Duration = .milliseconds(50)
    /// Display time of the matrix images for switching modes.
    static let modeImageSeconds = 1.0

    var onActivity: ((Activity) -> Void)?
    /// Called when the active mode changes, with the new mode or `nil` for off.
    var onModeChange: ((String?) -> Void)?

    /// Active mode, if any; its profile comes first. Setting it directly shows nothing on the matrix.
    var activeMode: String?

    private struct Context {
        var config: Config
        var chain: [Profile]
        var settings: Settings { config.settings }
    }

    /// A `hold` action in progress, with everything needed to release it.
    private struct HeldAction {
        var midi: MIDIAction
        var channel: UInt8
    }

    private let outputs: any Outputs
    private let config: @MainActor () -> Config
    private let frontmostApp: @MainActor () -> FrontmostApp?
    private let log: DebugLog?
    private let scheduler: any Scheduler
    private lazy var gestures = ButtonGestures(scheduler: scheduler) { [weak self] gesture in
        self?.trigger(gesture.rawValue, feedback: gesture.feedbackImage)
    }
    private var isButtonPressed = false
    private var held: HeldAction?
    /// Rotation not yet used up by `rotate_left`/`rotate_right` steps, per base event.
    private var rotationRest: [String: Int] = [:]
    private var controlChanges = ControlChangeTracker()

    init(
        outputs: any Outputs,
        config: @escaping @MainActor () -> Config,
        frontmostApp: @escaping @MainActor () -> FrontmostApp?,
        scheduler: any Scheduler,
        log: DebugLog? = nil
    ) {
        self.outputs = outputs
        self.config = config
        self.frontmostApp = frontmostApp
        self.scheduler = scheduler
        self.log = log
    }

    func handle(_ input: NuimoProtocol.Input) {
        switch input {
        case .button(let pressed):
            if pressed {
                buttonDown()
            } else {
                buttonUp()
            }
        case .rotation(let delta):
            gestures.rotated()
            rotate(by: delta, pressed: isButtonPressed)
        case .gesture(let gesture):
            trigger(gesture.rawValue, feedback: gesture.feedbackImage)
        }
    }

    /// Switches the mode, e.g. from the menu, and shows "M" or "X" on the matrix. Unknown modes are ignored.
    func switchMode(to name: String?) {
        if let name, config().modes[name] == nil {
            log?("Unknown mode \(name)")
            return
        }
        outputs.showMatrix(name == nil ? .modeOff : .modeOn, seconds: Self.modeImageSeconds)
        guard name != activeMode else { return }
        log?("Mode: \(name ?? "off")")
        activeMode = name
        onModeChange?(name)
    }

    /// Forgets button state and releases a held action, e.g. after the connection was lost.
    func reset() {
        gestures.reset()
        isButtonPressed = false
        if let held {
            self.held = nil
            sendHold(held, down: false)
        }
    }

    private func context() -> Context {
        let config = config()
        if let mode = activeMode, config.modes[mode] == nil {
            log?("Mode \(mode) no longer exists, switching it off")
            activeMode = nil
            onModeChange?(nil)
        }
        return Context(config: config, chain: config.profiles(for: frontmostApp(), mode: activeMode))
    }

    // MARK: Button

    private func buttonDown() {
        isButtonPressed = true
        let context = context()
        if let hold = holdAction(in: context) {
            held = hold
            sendHold(hold, down: true)
        } else {
            gestures.press()
        }
    }

    private func buttonUp() {
        isButtonPressed = false
        if let held {
            self.held = nil
            sendHold(held, down: false)
        } else {
            gestures.release()
        }
    }

    /// The `hold` action that applies now, or `nil` if `hold` is not mapped, is `none` or is invalid.
    private func holdAction(in context: Context) -> HeldAction? {
        guard let profile = context.chain.first(where: { $0["hold"] != nil }), let text = profile["hold"] else {
            return nil
        }
        let action: Action
        do {
            action = try Action(parsing: text)
        } catch {
            log?("[\(Self.label(context.chain))] hold → \(text): \(error)")
            return nil
        }
        guard case .midi(let midi) = action, midi.isHold else {
            if action != .none {
                log?("[\(Self.label(context.chain))] hold: '\(text)' only works with midi:note and midi:cc")
            }
            return nil
        }
        log?("[\(Self.label(context.chain))] hold → \(text)")
        report("hold", action: text, chain: context.chain)
        return HeldAction(midi: midi, channel: midi.resolvedChannel(default: context.settings.midiChannel))
    }

    private func sendHold(_ hold: HeldAction, down: Bool) {
        switch hold.midi.kind {
        case .note(let note):
            outputs.sendMIDI(
                down
                    ? .noteOn(channel: hold.channel, note: note, velocity: 127)
                    : .noteOff(channel: hold.channel, note: note))
        case .controlChange(let controller):
            outputs.sendMIDI(.controlChange(channel: hold.channel, controller: controller, value: down ? 127 : 0))
        case .relativeControlChange, .fixedControlChange, .programChange:
            break
        }
    }

    // MARK: Triggers

    private func trigger(_ event: String, feedback: MatrixImage?) {
        let context = context()
        guard let profile = context.chain.first(where: { $0[event] != nil }), let text = profile[event] else {
            log?("[\(Self.label(context.chain))] \(event) (not mapped)")
            report(event, action: nil, chain: context.chain)
            return
        }
        perform(text, for: event, in: context, feedback: feedback)
    }

    private func perform(_ text: String, for event: String, in context: Context, feedback: MatrixImage?) {
        log?("[\(Self.label(context.chain))] \(event) → \(text)")
        report(event, action: text, chain: context.chain)
        let action: Action
        do {
            action = try Action(parsing: text)
        } catch {
            log?("  \(error)")
            return
        }
        guard action.isTrigger else {
            log?("  '\(text)' does not work for \(event)")
            return
        }
        switch action {
        case .keys(let shortcut): outputs.sendKeys(shortcut)
        case .media(let key): outputs.sendMedia(key)
        case .shell(let command): outputs.runShell(command)
        case .midi(let midi): sendTrigger(midi, settings: context.settings)
        case .mode(let mode):
            apply(mode)
            return
        case .none, .volume, .scroll: return
        }
        if let feedback {
            outputs.showMatrix(feedback, seconds: 0.8)
        }
    }

    private func sendTrigger(_ midi: MIDIAction, settings: Settings) {
        let channel = midi.resolvedChannel(default: settings.midiChannel)
        switch midi.kind {
        case .note(let note):
            outputs.sendMIDI(.noteOn(channel: channel, note: note, velocity: 127))
            scheduler.schedule(after: Self.midiTriggerLength) { [outputs] in
                outputs.sendMIDI(.noteOff(channel: channel, note: note))
            }
        case .controlChange(let controller):
            outputs.sendMIDI(.controlChange(channel: channel, controller: controller, value: 127))
            scheduler.schedule(after: Self.midiTriggerLength) { [outputs] in
                outputs.sendMIDI(.controlChange(channel: channel, controller: controller, value: 0))
            }
        case .fixedControlChange(let controller, let value):
            outputs.sendMIDI(.controlChange(channel: channel, controller: controller, value: value))
        case .programChange(let program):
            outputs.sendMIDI(.programChange(channel: channel, program: program))
        case .relativeControlChange:
            break
        }
    }

    private func apply(_ mode: ModeAction) {
        switch mode {
        case .on(let name):
            switchMode(to: name)
        case .off:
            switchMode(to: nil)
        case .toggle(let name):
            switchMode(to: activeMode == name ? nil : name)
        }
    }

    // MARK: Rotation

    private func rotate(by delta: Int, pressed: Bool) {
        let context = context()
        let base = pressed ? "rotate_pressed" : "rotate"
        let left = "\(base)_left"
        let right = "\(base)_right"
        for profile in context.chain {
            if let text = profile[base] {
                rotateContinuously(by: delta, text: text, event: base, in: context)
                return
            }
            if profile[left] != nil || profile[right] != nil {
                let step = context.settings.rotateStep
                var rest = rotationRest[base, default: 0] + delta
                while abs(rest) >= step {
                    let event = rest > 0 ? right : left
                    rest -= rest > 0 ? step : -step
                    if let text = profile[event] {
                        perform(text, for: event, in: context, feedback: nil)
                    }
                }
                rotationRest[base] = rest
                return
            }
        }
    }

    private func rotateContinuously(by delta: Int, text: String, event: String, in context: Context) {
        report(event, action: text, chain: context.chain)
        let action: Action
        do {
            action = try Action(parsing: text)
        } catch {
            log?("[\(Self.label(context.chain))] \(event) → \(text): \(error)")
            return
        }
        let turns = Double(delta) / Double(NuimoProtocol.rotationPerTurn)
        switch action {
        case .volume:
            if let volume = outputs.changeVolume(by: turns * 100) {
                outputs.showMatrix(.level(volume), seconds: 1.5)
            } else {
                log?("Output device has no volume control")
            }
        case .scroll(let modifiers):
            let pixels = Int((Double(delta) * context.settings.scrollSpeed).rounded(.toNearestOrEven))
            if pixels != 0 {
                outputs.scroll(pixels: pixels, modifiers: modifiers)
            }
        case .midi(let midi) where midi.isContinuous:
            rotate(midi, by: turns * context.settings.midiCCPerTurn, settings: context.settings)
        case .none:
            break
        case .keys, .media, .shell, .midi, .mode:
            log?(
                "[\(Self.label(context.chain))] \(event): '\(text)' does not work for rotation, use \(event)_left/_right"
            )
        }
    }

    private func rotate(_ midi: MIDIAction, by change: Double, settings: Settings) {
        let channel = midi.resolvedChannel(default: settings.midiChannel)
        switch midi.kind {
        case .controlChange(let controller):
            let (value, changed) = controlChanges.turnAbsolute(channel: channel, controller: controller, by: change)
            if changed {
                outputs.sendMIDI(.controlChange(channel: channel, controller: controller, value: value))
            }
            outputs.showMatrix(.level(Double(value) * 100 / 127), seconds: 1.5)
        case .relativeControlChange(let controller):
            let steps = controlChanges.turnRelative(channel: channel, controller: controller, by: change)
            for value in settings.midiRelative.values(for: steps) {
                outputs.sendMIDI(.controlChange(channel: channel, controller: controller, value: value))
            }
        case .note, .fixedControlChange, .programChange:
            break
        }
    }

    // MARK: Reporting

    private func report(_ event: String, action: String?, chain: [Profile]) {
        onActivity?(Activity(event: event, action: action, profile: Self.applyingProfile(chain)))
    }

    /// The most specific profile in the chain, which the menu shows.
    private static func applyingProfile(_ chain: [Profile]) -> Profile.Kind {
        chain.first?.kind ?? .standard
    }

    private static func label(_ chain: [Profile]) -> String {
        switch applyingProfile(chain) {
        case .mode(let name): "mode \(name)"
        case .app(let name): name
        case .standard: "default"
        }
    }
}
