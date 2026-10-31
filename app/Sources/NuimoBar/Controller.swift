/// Turns input from the Nuimo into actions: event → profile → action.
///
/// Profiles are searched in the order active mode, app in front, standard. The first profile that contains
/// the event decides; `none` silences it without falling back. For rotation, the first profile with either
/// `rotate` or `rotate_left`/`rotate_right` decides.
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

    var onActivity: ((Activity) -> Void)?
    /// Active mode, if any; its profile comes first.
    var activeMode: String?

    private let outputs: any Outputs
    private let config: @MainActor () -> Config
    private let frontmostApp: @MainActor () -> FrontmostApp?
    private let log: DebugLog?
    private let scheduler: any Scheduler
    private lazy var gestures = ButtonGestures(scheduler: scheduler) { [weak self] gesture in
        self?.trigger(gesture.rawValue, feedback: gesture.feedbackImage)
    }
    /// Rotation not yet used up by `rotate_left`/`rotate_right` steps, per base event.
    private var rotationRest: [String: Int] = [:]

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
                gestures.press()
            } else {
                gestures.release()
            }
        case .rotation(let delta):
            gestures.rotated()
            rotate(by: delta, pressed: gestures.isPressed)
        case .gesture(let gesture):
            trigger(gesture.rawValue, feedback: gesture.feedbackImage)
        }
    }

    /// Forgets button state, e.g. after the connection was lost.
    func reset() {
        gestures.reset()
    }

    private func context() -> (settings: Settings, chain: [Profile]) {
        let config = config()
        return (config.settings, config.profiles(for: frontmostApp(), mode: activeMode))
    }

    private func trigger(_ event: String, feedback: MatrixImage?) {
        let (_, chain) = context()
        guard let profile = chain.first(where: { $0[event] != nil }), let text = profile[event] else {
            log?("[\(Self.label(chain))] \(event) (not mapped)")
            report(event, action: nil, chain: chain)
            return
        }
        perform(text, for: event, in: chain, feedback: feedback)
    }

    private func perform(_ text: String, for event: String, in chain: [Profile], feedback: MatrixImage?) {
        log?("[\(Self.label(chain))] \(event) → \(text)")
        report(event, action: text, chain: chain)
        let action: Action
        do {
            action = try Action(parsing: text)
        } catch {
            log?("  \(error)")
            return
        }
        guard action.isTrigger else {
            log?("  '\(text)' only works for rotate and rotate_pressed")
            return
        }
        switch action {
        case .keys(let shortcut): outputs.sendKeys(shortcut)
        case .media(let key): outputs.sendMedia(key)
        case .shell(let command): outputs.runShell(command)
        case .none, .volume, .scroll: return
        }
        if let feedback {
            outputs.showMatrix(feedback, seconds: 0.8)
        }
    }

    private func rotate(by delta: Int, pressed: Bool) {
        let (settings, chain) = context()
        let base = pressed ? "rotate_pressed" : "rotate"
        let left = "\(base)_left"
        let right = "\(base)_right"
        for profile in chain {
            if let text = profile[base] {
                rotateContinuously(by: delta, text: text, event: base, settings: settings, chain: chain)
                return
            }
            if profile[left] != nil || profile[right] != nil {
                let step = settings.rotateStep
                var rest = rotationRest[base, default: 0] + delta
                while abs(rest) >= step {
                    let event = rest > 0 ? right : left
                    rest -= rest > 0 ? step : -step
                    if let text = profile[event] {
                        perform(text, for: event, in: chain, feedback: nil)
                    }
                }
                rotationRest[base] = rest
                return
            }
        }
    }

    private func rotateContinuously(by delta: Int, text: String, event: String, settings: Settings, chain: [Profile]) {
        report(event, action: text, chain: chain)
        let action: Action
        do {
            action = try Action(parsing: text)
        } catch {
            log?("[\(Self.label(chain))] \(event) → \(text): \(error)")
            return
        }
        switch action {
        case .volume:
            let percent = Double(delta) * 100 / Double(NuimoProtocol.rotationPerTurn)
            if let volume = outputs.changeVolume(by: percent) {
                outputs.showMatrix(.level(volume), seconds: 1.5)
            } else {
                log?("Output device has no volume control")
            }
        case .scroll(let modifiers):
            let pixels = Int((Double(delta) * settings.scrollSpeed).rounded(.toNearestOrEven))
            if pixels != 0 {
                outputs.scroll(pixels: pixels, modifiers: modifiers)
            }
        case .none:
            break
        case .keys, .media, .shell:
            log?("[\(Self.label(chain))] \(event): '\(text)' does not work for rotation, use \(event)_left/_right")
        }
    }

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
