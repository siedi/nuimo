/// Switching modes: `mode:<Name>`, `mode:off`, `mode:toggle:<Name>`.
enum ModeAction: Equatable, Sendable {
    case on(String)
    case off
    case toggle(String)

    /// Parses the part after `mode:`.
    init(parsing text: String) throws(ActionParseError) {
        if text == "off" {
            self = .off
        } else if text.hasPrefix("toggle:") {
            let name = String(text.dropFirst("toggle:".count))
            guard !name.isEmpty else { throw .missingArgument("mode:toggle") }
            self = .toggle(name)
        } else {
            self = .on(text)
        }
    }
}
