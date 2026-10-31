/// A section of `config.toml` that maps event names to action texts.
struct Profile: Equatable, Sendable {
    /// Where the profile comes from; also what the menu shows.
    enum Kind: Equatable, Sendable {
        case mode(String)
        /// App profile, with the app's display name.
        case app(String)
        case standard
    }

    var kind: Kind
    var entries: [String: String]

    init(kind: Kind, entries: [String: String] = [:]) {
        self.kind = kind
        self.entries = entries
    }

    subscript(event: String) -> String? {
        entries[event]
    }
}
