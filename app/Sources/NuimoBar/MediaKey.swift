/// Media keys; raw values are the names in `config.toml`.
enum MediaKey: String, CaseIterable, Sendable {
    case playPause = "playpause"
    case next
    case previous
    case mute

    /// `NX_KEYTYPE_*` code for system-defined media key events.
    var code: Int {
        switch self {
        case .playPause: 16
        case .next: 17
        case .previous: 18
        case .mute: 7
        }
    }
}
