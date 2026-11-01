/// An action from `config.toml`, e.g. `keys:opt+return`, `volume` or `midi:note:36`.
enum Action: Equatable, Sendable {
    case keys(KeyShortcut)
    case media(MediaKey)
    case shell(String)
    /// Continuous: system volume.
    case volume
    /// Continuous: scroll wheel at the mouse position, optionally with modifiers.
    case scroll(KeyModifiers)
    case midi(MIDIAction)
    case mode(ModeAction)
    /// Do nothing, and do not fall back to later profiles.
    case none

    init(parsing text: String) throws(ActionParseError) {
        let kind: Substring
        let argument: String?
        if let colon = text.firstIndex(of: ":") {
            kind = text[..<colon]
            argument = String(text[text.index(after: colon)...])
        } else {
            kind = text[...]
            argument = nil
        }

        switch kind {
        case "keys":
            self = .keys(try KeyShortcut(parsing: try Self.required(argument, for: "keys")))
        case "media":
            let name = try Self.required(argument, for: "media")
            guard let key = MediaKey(rawValue: name.lowercased()) else { throw .unknownMediaKey(name) }
            self = .media(key)
        case "shell":
            self = .shell(try Self.required(argument, for: "shell"))
        case "volume":
            guard argument == nil else { throw .unexpectedArgument("volume") }
            self = .volume
        case "scroll":
            if let argument {
                self = .scroll(try KeyModifiers(parsing: argument))
            } else {
                self = .scroll([])
            }
        case "midi":
            self = .midi(try MIDIAction(parsing: try Self.required(argument, for: "midi")))
        case "mode":
            self = .mode(try ModeAction(parsing: try Self.required(argument, for: "mode")))
        case "none":
            guard argument == nil else { throw .unexpectedArgument("none") }
            self = .none
        default:
            throw .unknownAction(text)
        }
    }

    /// Whether the action works for `rotate` and `rotate_pressed`.
    var isContinuous: Bool {
        switch self {
        case .volume, .scroll, .none: true
        case .midi(let midi): midi.isContinuous
        case .keys, .media, .shell, .mode: false
        }
    }

    /// Whether the action works for discrete events like `press` or `rotate_left`.
    var isTrigger: Bool {
        switch self {
        case .keys, .media, .shell, .mode, .none: true
        case .midi(let midi): midi.isTrigger
        case .volume, .scroll: false
        }
    }

    /// Whether the action works for `hold`.
    var isHold: Bool {
        switch self {
        case .none: true
        case .midi(let midi): midi.isHold
        case .keys, .media, .shell, .mode, .volume, .scroll: false
        }
    }

    private static func required(_ argument: String?, for kind: String) throws(ActionParseError) -> String {
        guard let argument, !argument.isEmpty else { throw .missingArgument(kind) }
        return argument
    }
}
