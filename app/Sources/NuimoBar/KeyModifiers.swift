/// Modifier keys of a shortcut or scroll action.
struct KeyModifiers: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let shift = KeyModifiers(rawValue: 1 << 1)
    static let control = KeyModifiers(rawValue: 1 << 2)
    static let option = KeyModifiers(rawValue: 1 << 3)

    /// Names as written in `config.toml`.
    static let names: [String: KeyModifiers] = [
        "cmd": .command, "shift": .shift, "ctrl": .control, "opt": .option, "alt": .option,
    ]

    /// Parses names joined with `+`, e.g. `ctrl+opt`. Case is ignored.
    init(parsing text: String) throws(ActionParseError) {
        self = []
        for name in text.lowercased().split(separator: "+", omittingEmptySubsequences: false) {
            guard let modifier = Self.names[String(name)] else {
                throw .unknownModifier(String(name))
            }
            insert(modifier)
        }
    }

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
